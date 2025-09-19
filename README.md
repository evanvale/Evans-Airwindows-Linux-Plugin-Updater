# Evan's Airwindows Linux Plugin Updater

A shell script that automatically downloads and installs the latest [Airwindows Consolidated](https://github.com/baconpaul/airwin2rack) plugin for Linux.

**Airwindows Consolidated** is a single plugin that contains all 350+ Airwindows effects in one streamlined interface, rather than individual plugin files. 

This script is written to be as POSIX-friendly as possible, so it should work on macOS with minimal changes and be relatively easy to port to Windows (WSL/Git Bash).

## What it does

- Downloads the latest Airwindows Consolidated plugin release from GitHub
- Verifies checksums when available  
- Extracts and overwrites both .clap and VST formats with newest version
- Handles multiple plugin directory locations
- Has fallbacks for all tools, so it should work on almost any Linux distro

## Quick start

```bash
# Make executable
chmod +x airwindows_updater.sh

# Run it (first time will prompt for plugin directory)
./airwindows_updater.sh

# Or set your plugin directory first
export PLUGIN_DIR=~/.vst3
./airwindows_updater.sh
```

## Options

- `-q` - Quiet mode (minimal output)
- `-v` - Verbose mode (show command output) 
- `-h` - Show help

## Requirements

**Required:**
- `wget` or `curl` for downloading
- One of: `unzip`, `7z`, `7za`, `bsdtar`, or `busybox unzip` for extraction

**Optional:**
- `jq` for faster GitHub API parsing
- `sha256sum` for checksum verification

## License

Public domain. Do whatever you want with this.

## Credits

Script written by Claude AI.

Downloads plugins from [baconpaul/airwin2rack](https://github.com/baconpaul/airwin2rack), which combines all of Chris Johnson's [Airwindows](https://www.airwindows.com/) audio plugins into a single interface with classifications and a search function.
