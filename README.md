# [lurker](https://www.techopedia.com/definition/8155/lurker)
A simple terminal client for reading Hacker News, written entirely in bash.

### Install
Install with [Homebrew](https://brew.sh): `brew install wcarhart/tools/lurker`.

Or, download or clone this repository and run `./lurker`.

### Examples
Read Hacker News headlines...

![lurker demo 1](https://i.imgur.com/v6kNmTb.png)

Read comments for a specific post...

![lurker demo 2](https://i.imgur.com/n68f059.png)

### Available commands
```
> help
Available commands:
  help        - show this help menu
  read <ID>   - open the comment thread for post ID
  open <ID>   - open the URL for the post ID in your default browser
  smoosh <ID> - (beta) summarize an article for post ID via smoosh (see https://github.com/wcarhart/smoosh)
  <ID>        - get info for post ID
  more        - show the next 10 posts (up to 500)
  less        - show the previous 10 posts
  back        - show the previous list of posts again
  clear       - clear the screen
  exit        - quit Lurker
```
