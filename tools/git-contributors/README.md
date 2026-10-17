# git-contributors.py

> **Legacy reference utility.** This script regenerates the retained C++ engine's HOG credits. It is not the Revival release-note, attribution, or publishing workflow.

**git-contributors.py** - script to generate contributors list from git history.

## Requirements

* Recent python (3.12+)
* GitPython package (https://pypi.org/project/GitPython/)

## Usage

```sh
cd tools/git-contributors
python3 git-contributors.py
```

Review and commit `scripts/data/fullhog/oscredits.txt` only when maintaining the retained C++ reference release.

Regenerate the file before a retained C++ reference release.

## Customization

Tool provides two ways of customization:

* Exclude particular name from list of contributors (file `no-add.txt`,
  one name per line, comments begins with `#`).
* Replace name in list of contributors with other one (file `map-names.txt`,
  one entry per line in format `git_name:replace_name`, comments begins with `#`).
