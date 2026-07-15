#!/usr/bin/env ruby
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Evidence-only parser for the owned Training capture. It follows the released
# loader's field order for one D3LV-127 checkpoint. It is not D3Import, a
# runtime legacy reader, or a supported general D3L tool. Use its output to
# author the first D3Import red assertions, then delete it before production
# import implementation begins.

require "digest"

class Cursor
  attr_reader :position

  def initialize(bytes)
    @bytes = bytes
    @position = 0
  end

  def take(count)
    value = @bytes.byteslice(@position, count)
    raise "short read at #{@position}, need #{count}" unless value&.bytesize == count

    @position += count
    value
  end

  def u8 = take(1).unpack1("C")
  def u16 = take(2).unpack1("S<")
  def i16 = take(2).unpack1("s<")
  def u32 = take(4).unpack1("L<")
  def i32 = take(4).unpack1("l<")
  def skip(count) = take(count)

  def c_string
    terminator = @bytes.index(0.chr, @position)
    raise "unterminated string at #{@position}" unless terminator

    value = @bytes.byteslice(@position, terminator - @position)
    @position = terminator + 1
    value
  end
end

archive_path = ARGV.fetch(0) do
  abort "usage: training_d3l_audit.rb <owned-training.mn3>"
end

archive = File.binread(archive_path)
raise "expected HOG2" unless archive.byteslice(0, 4) == "HOG2"

entry_count = archive.byteslice(4, 4).unpack1("L<")
first_payload = archive.byteslice(8, 4).unpack1("L<")
entries = []
payload_cursor = first_payload

entry_count.times do |index|
  record = archive.byteslice(68 + index * 48, 48)
  raise "short HOG2 record #{index}" unless record&.bytesize == 48

  name = record.byteslice(0, 36).split(0.chr, 2).first
  flags, length, timestamp = record.byteslice(36, 12).unpack("L<L<L<")
  raise "HOG2 entry #{index} exceeds archive" if payload_cursor + length > archive.bytesize

  entries << {
    index: index,
    name: name,
    flags: flags,
    length: length,
    timestamp: timestamp,
    offset: payload_cursor
  }
  payload_cursor += length
end

matches = entries.select { |entry| entry[:name].downcase == "trainingmission.d3l" }
raise "expected one TrainingMission.d3l, found #{matches.length}" unless matches.length == 1

level_entry = matches.fetch(0)
level = archive.byteslice(level_entry[:offset], level_entry[:length])
raise "expected D3LV" unless level.byteslice(0, 4) == "D3LV"

version = level.byteslice(4, 4).unpack1("L<")
raise "this evidence parser supports only D3LV 127, found #{version}" unless version == 127

chunks = {}
position = 8

while position < level.bytesize
  name = level.byteslice(position, 4)
  size = level.byteslice(position + 4, 4).unpack1("L<")
  raise "invalid chunk #{name.inspect} at #{position}" if size < 4
  raise "chunk #{name.inspect} exceeds D3L" if position + 4 + size > level.bytesize
  raise "duplicate chunk #{name.inspect}" if chunks.key?(name)

  chunks[name] = level.byteslice(position + 8, size - 4)
  position += 4 + size
end

raise "chunk walk ended at #{position}/#{level.bytesize}" unless position == level.bytesize

generic_cursor = Cursor.new(chunks.fetch("GNNM"))
generic_names = Array.new(generic_cursor.u32) { generic_cursor.c_string }

room_cursor = Cursor.new(chunks.fetch("ROOM"))
room_count = room_cursor.u32
room_memory = [
  room_cursor.u32,
  room_cursor.u32,
  room_cursor.u32,
  room_cursor.u32
]
rooms = {}

room_count.times do
  room_index = room_cursor.i16
  vertex_count = room_cursor.u32
  face_count = room_cursor.u32
  portal_count = room_cursor.u32
  room_name = room_cursor.c_string

  room_cursor.skip(12) # path point
  room_cursor.skip(vertex_count * 12)

  faces = []

  face_count.times do |face_index|
    face_vertex_count = room_cursor.u8
    room_cursor.skip(face_vertex_count * 2)
    room_cursor.skip(face_vertex_count * 9)

    flags = room_cursor.u16
    portal_number = room_cursor.u8
    texture = room_cursor.u16
    lightmap_info = 65_535

    if (flags & 1) != 0
      lightmap_info = room_cursor.u16
      room_cursor.skip(face_vertex_count * 8)
    end

    room_cursor.u8 # light multiple
    special = room_cursor.u8

    if special != 0
      room_cursor.u8 # type
      instance_count = room_cursor.u8
      smooth = room_cursor.u8
      smooth_vertex_count = smooth != 0 ? room_cursor.u8 : 0
      room_cursor.skip(instance_count * 14)
      room_cursor.skip(smooth_vertex_count * 12)
    end

    faces << {
      index: face_index,
      flags: flags,
      portal_number: portal_number,
      texture: texture,
      lightmap_info: lightmap_info
    }
  end

  portals = []

  portal_count.times do |portal_index|
    flags = room_cursor.u32
    face = room_cursor.i16
    connected_room = room_cursor.i32
    connected_portal = room_cursor.i32
    bnode = room_cursor.i16
    room_cursor.skip(12)
    combine_master = room_cursor.i32

    portals << {
      index: portal_index,
      flags: flags,
      face: face,
      connected_room: connected_room,
      connected_portal: connected_portal,
      bnode: bnode,
      combine_master: combine_master
    }
  end

  room_flags = room_cursor.u32
  room_cursor.skip(2) # pulse time and offset
  room_cursor.i16     # mirror face

  if (room_flags & 2) != 0
    room_cursor.u8
    room_cursor.u8
    room_cursor.i32
    room_cursor.skip(4)
  end

  volume_light_present = room_cursor.u8

  if volume_light_present == 1
    volume_count = room_cursor.u32 * room_cursor.u32 * room_cursor.u32
    compression = room_cursor.u8

    if compression == 0
      room_cursor.skip(volume_count)
    else
      produced = 0

      while produced < volume_count
        command = room_cursor.u8
        room_cursor.u8
        produced += command == 0 ? 1 : command
      end

      raise "invalid volume-light RLE" unless produced == volume_count
    end
  end

  room_cursor.skip(16) # fog
  room_cursor.c_string # ambient pattern
  room_cursor.u8       # reverb
  room_cursor.skip(5)  # damage and damage type

  rooms[room_index] = {
    name: room_name,
    vertex_count: vertex_count,
    faces: faces,
    portals: portals
  }
end

room_trailing = chunks.fetch("ROOM").byteslice(
  room_cursor.position,
  chunks.fetch("ROOM").bytesize - room_cursor.position
)
raise "unexpected ROOM tail #{room_trailing.unpack1("H*")}" unless room_trailing.bytes.all?(&:zero?)

object_cursor = Cursor.new(chunks.fetch("OBJS"))
object_count = object_cursor.u32
objects = []

object_count.times do
  handle = object_cursor.u32
  type = object_cursor.u8
  stored_id = object_cursor.u16
  instance_name = object_cursor.c_string
  flags = object_cursor.u32

  object_cursor.i16 if type == 17 # door shields
  room = object_cursor.i32
  object_cursor.skip(12)          # position
  object_cursor.skip(36)          # orientation
  object_cursor.skip(3)           # contains fields
  object_cursor.skip(4)           # lifeleft

  if type == 24 # OBJ_SOUNDSOURCE under D3LV 127
    object_cursor.c_string
    object_cursor.skip(4)
  end

  script_length = object_cursor.u8
  object_cursor.skip(script_length)
  module_length = object_cursor.u8
  object_cursor.skip(module_length)

  lightmap_data = object_cursor.u8

  if lightmap_data != 0
    object_cursor.u8.times do
      object_cursor.u16.times do
        object_cursor.u16
        object_cursor.skip(24)
        lightmap_vertex_count = object_cursor.u8
        object_cursor.skip(lightmap_vertex_count * 8)
      end
    end
  end

  objects << {
    slot: handle & 0x7ff,
    type: type,
    stored_id: stored_id,
    stored_name: generic_names.fetch(stored_id),
    instance_name: instance_name,
    room: room,
    flags: flags
  }
end

raise "OBJS parser did not consume chunk" unless object_cursor.position == chunks.fetch("OBJS").bytesize

path_count = chunks.fetch("PATH").byteslice(0, 2).unpack1("S<")
goal_version, goal_count = chunks.fetch("LVLG").byteslice(0, 4).unpack("S<S<")
aabb_highest = chunks.fetch("AABB").byteslice(0, 4).unpack1("L<")
parsed_portals = rooms.values.sum { |room| room[:portals].length }
room3 = rooms.fetch(3)

puts "archive_bytes=#{archive.bytesize}"
puts "archive_sha256=#{Digest::SHA256.hexdigest(archive)}"
puts "hog_tag=HOG2"
puts "hog_entries=#{entry_count}"
puts "hog_first_payload=#{first_payload}"
puts "level_entry_index=#{level_entry[:index]}"
puts "level_entry_name=#{level_entry[:name]}"
puts "level_offset=#{level_entry[:offset]}"
puts "level_bytes=#{level_entry[:length]}"
puts "level_sha256=#{Digest::SHA256.hexdigest(level)}"
puts "level_tag=D3LV"
puts "level_version=#{version}"
puts "chunk_walk=#{position}/#{level.bytesize}"
puts "rooms=#{room_count}"
puts "room_index_min=#{rooms.keys.min}"
puts "room_index_max=#{rooms.keys.max}"
puts "room_indices_missing=#{((rooms.keys.min..rooms.keys.max).to_a - rooms.keys).join(",")}"
puts "aabb_highest_room_index=#{aabb_highest}"
puts "room_memory_vertices=#{room_memory[0]}"
puts "room_memory_faces=#{room_memory[1]}"
puts "room_memory_face_vertices=#{room_memory[2]}"
puts "room_memory_directed_portals=#{room_memory[3]}"
puts "parsed_directed_portals=#{parsed_portals}"
puts "objects=#{object_count}"
puts "terrain_cells_fixed=#{256 * 256}"
puts "paths=#{path_count}"
puts "goal_chunk_version=#{goal_version}"
puts "goals=#{goal_count}"
puts "room_chunk_trailing_zero_bytes=#{room_trailing.bytesize}"

[2, 3, 4].each do |room_index|
  room = rooms.fetch(room_index)
  puts [
    "room",
    "index=#{room_index}",
    "name=#{room[:name].inspect}",
    "vertices=#{room[:vertex_count]}",
    "faces=#{room[:faces].length}",
    "portals=#{room[:portals].length}"
  ].join(" ")

  room[:portals].each do |portal|
    puts [
      "portal",
      "room=#{room_index}",
      "index=#{portal[:index]}",
      "face=#{portal[:face]}",
      "connected_room=#{portal[:connected_room]}",
      "connected_portal=#{portal[:connected_portal]}",
      "flags=#{portal[:flags]}"
    ].join(" ")
  end
end

room3[:faces].each do |face|
  puts [
    "face",
    "room=3",
    "index=#{face[:index]}",
    "texture=#{face[:texture]}",
    "lightmap_info=#{face[:lightmap_info]}",
    "flags=#{face[:flags]}",
    "portal_number=#{face[:portal_number]}"
  ].join(" ")
end

objects.select { |object| object[:room] == 3 }.each do |object|
  puts [
    "object",
    "room=3",
    "slot=#{object[:slot]}",
    "type=#{object[:type]}",
    "stored_generic_index=#{object[:stored_id]}",
    "stored_generic_name=#{object[:stored_name].inspect}",
    "instance_name=#{object[:instance_name].inspect}"
  ].join(" ")
end
