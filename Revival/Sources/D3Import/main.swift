import Darwin

fputs(
    "usage: D3Import --contract 1 --source <directory> --staging <directory> --destination <directory> --scope <scope> --report <json-path>\n",
    stderr
)
exit(EX_USAGE)
