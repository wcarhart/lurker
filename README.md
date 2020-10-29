<p align="center"><img alt="lurker logo" src="logo.png" /></p>

<h1 align="center">lurker</h1>
<h5 align="center">Hacker News terminal client</h5>

### Overview
Lurker is a simple terminal client for reading [Hacker News](https://news.ycombinator.com/), written entirely in bash.

### Documentation
Please visit the [documentation site](https://willcarhart.dev/docs/lurker) for full documentation.

### Install
Install with [Homebrew](https://brew.sh):
```bash
brew install wcarhart/tools/lurker
```

Or, download or clone this repository and run:
```bash
./lurker
```

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
  open <ID>   - open the URL for the post ID in your default browser (only available on macOS)
  copy <ID>   - copy the URL for the post ID to the clipboard (only available on macOS)
  hack <ID>   - open the Hacker News link for the post ID in your default browser (only available on macOS)
  smoosh <ID> - summarize (smoosh) the content from the URL for post ID (only available on macOS)
  user <ID>   - show info for user ID
  <ID>        - get info for post ID
  more        - show the next 10 posts (up to 500)
  less        - show the previous 10 posts
  back        - show the previous list of posts again
  refresh     - refresh the master post list, which will reset the ordering of posts
  clear       - clear the screen
  exit        - quit lurker
```
Learn more about [smoosh](https://github.com/wcarhart/smoosh).
