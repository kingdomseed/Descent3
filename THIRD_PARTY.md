> **Historical upstream record.** These components belong to the retained C++ reference tree. They are not selected runtime dependencies for the Swift/Metal Revival product. See [Architecture](docs/revival/architecture.md) and [Engineering principles](docs/revival/engineering-principles.md).

# Third party components

This file records license notices for selected vendored and externally resolved
components used by the retained C++ reference tree. The current external build
dependency list lives in `vcpkg.json`; this file is not the complete build
manifest.

## libacm

libacm - library for InterPlay ACM Audio format. https://github.com/markokr/libacm

* third_party/libacm/decode.c
* third_party/libacm/libacm.h

The libacm core code is licensed under minimal BSD/ISC license.

```
Copyright (c) 2004-2010, Marko Kreen

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```

## libmve

The MVE decoder and player core is derived from the D2X project. https://github.com/btb/d2x

[@c030c453](https://github.com/btb/d2x/tree/c030c4531ad19f1658ea9635ff4ee6861e1d15e0)

* libmve/decoder8.cpp
* libmve/decoder16.cpp
* libmve/decoders.h
* libmve/mve_audio.cpp
* libmve/mve_audio.h
* libmve/mvelib.cpp
* libmve/mvelib.h
* libmve/mveplay.cpp

Descent Developers integration code:

* libmve/movie_sound.cpp
* libmve/movie_sound.h
* libmve/sound_interface.h

All listed libmve files are licensed under GPL-3.0-or-later. The D2X-derived files carry this notice:

```
Copyright (C) 2002-2024 D2X Project

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
```

## plog

Portable, simple and extensible C++ logging library.

* Resolved externally through `vcpkg.json`; no plog source is vendored under `third_party/`.

The plog code is licensed under MIT license.

```
Copyright (c) 2022 Sergey Podobry

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## stb

`stb_image_write.h` is the upstream single-file image writer from stb. https://github.com/nothings/stb

* third_party/stb/stb_image_write.h

The upstream header is offered as public domain or MIT; its MIT notice follows.

```
Copyright (c) 2017 Sean Barrett
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Descent Developers supplies the GPL-3.0-or-later implementation wrapper that compiles the header:

* third_party/stb/stb.cpp
