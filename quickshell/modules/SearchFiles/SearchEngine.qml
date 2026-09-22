import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: engine

    property string query: ""
    property var rawResults: []
    property bool isSearching: searchProc.running
    property int debounceMs: 150
    property int maxResults: 35
    property int maxRawResults: 200
    property int currentGeneration: 0

    property string selectedCategory: "all"   // all, folder, music, video, document
    property string folderFilter: "all"       // all, hidden, normal
    property string extFilter: "all"

    readonly property var musicExts: ["mp3","flac","wav","m4a","ogg","opus"]
    readonly property var videoExts: ["mp4","mkv","webm","mov","avi"]
    readonly property var docExts: ["doc","docx","docm","dot","dotx","xls","xlsx","xlsm","xlsb","xlt","xltx","ppt","pptx","pptm","pps","ppsx","pdf","txt"]

    function extOf(path) {
        const base = path.split("/").pop();
        const idx = base.lastIndexOf(".");
        return idx > 0 ? base.slice(idx + 1).toLowerCase() : "";
    }

    function categoryOf(item) {
        if (item.type === "dir") return "folder";
        const ext = extOf(item.path);
        if (musicExts.includes(ext)) return "music";
        if (videoExts.includes(ext)) return "video";
        if (docExts.includes(ext)) return "document";
        return "other";
    }

    property var results: {
        const filtered = rawResults.filter(item => {
            if (selectedCategory === "all") return true;
            const cat = categoryOf(item);
            if (selectedCategory === "folder") {
                if (cat !== "folder") return false;
                if (folderFilter === "all") return true;
                const isHidden = item.path.split("/").pop().startsWith(".");
                return folderFilter === "hidden" ? isHidden : !isHidden;
            }
            if (cat !== selectedCategory) return false;
            if (extFilter === "all") return true;
            return extOf(item.path) === extFilter;
        });
        return filtered.slice(0, maxResults);
    }

    function stop() {
        debounceTimer.stop();
        if (searchProc.running) {
            searchProc.running = false;
        }
    }

    function resetFilters() {
        selectedCategory = "all";
        folderFilter = "all";
        extFilter = "all";
    }

    onQueryChanged: {
        const q = query.trim();
        if (q.length < 2) {
            stop();
            engine.rawResults = [];
            return;
        }
        debounceTimer.restart();
    }

    Timer {
        id: debounceTimer
        interval: engine.debounceMs
        repeat: false
        onTriggered: {
            if (searchProc.running) {
                searchProc.running = false;
            }

            engine.rawResults = [];
            engine.currentGeneration++;
            searchProc.myGen = engine.currentGeneration;

            searchProc.command = [
                "bash", "-c",
                'query="$1"; ' +
                'base_dir="$HOME/.config/quickshell/modules/SearchFiles"; ' +
                'excl_file="$base_dir/exclusions"; ' +
                'filter_file="$base_dir/filter"; ' +

                // Baseline noise excludes, always on, regardless of user's file
                'default_excludes=(".git" ".cache" ".npm" ".cargo" ".rustup" "node_modules" ' +
                '"__pycache__" ".venv" "venv" "target" "build" "dist" ".local/share/Trash" ".steam" ".wine"); ' +

                // 1. Gather roots
                'mapfile -t targets < <(' +
                '  printf "%s\\n" "$HOME"; ' +
                '  findmnt -lno TARGET 2>/dev/null | grep -E "^/(run/media|mnt|media|data|storage)/"' +
                '); ' +
                'valid=(); ' +
                'for t in "${targets[@]}"; do [ -d "$t" ] && valid+=("$t"); done; ' +
                '[ ${#valid[@]} -eq 0 ] && exit 0; ' +

                // 2. Parse exclusions (default + user file), anchored at any depth via **/
                'fd_excludes=(); ' +
                'for e in "${default_excludes[@]}"; do fd_excludes+=(--exclude "**/$e"); done; ' +
                'if [ -f "$excl_file" ]; then ' +
                '  while IFS= read -r line || [ -n "$line" ]; do ' +
                '    line=$(echo "$line" | sed -e "s/#.*//" -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//"); ' +
                '    [ -n "$line" ] && fd_excludes+=(--exclude "**/$line"); ' +
                '  done < "$excl_file"; ' +
                'fi; ' +

                // 3. Parse filter file (allowed extensions)
                'fd_exts=(); ' +
                'if [ -f "$filter_file" ]; then ' +
                '  while IFS= read -r ext || [ -n "$ext" ]; do ' +
                '    ext=$(echo "$ext" | sed -e "s/#.*//" -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//" -e "s/^\\.//"); ' +
                '    [ -n "$ext" ] && fd_exts+=(-e "$ext"); ' +
                '  done < "$filter_file"; ' +
                'fi; ' +

                // 4. Search, normalize trailing slashes, then guarantee dot-directories always survive the cap
                'if ! command -v fd >/dev/null 2>&1; then ' +
                '  find "${valid[@]}" -iname "*$query*" 2>/dev/null | sed "s/^/F\\t/" | head -n ' + engine.maxRawResults + '; ' +
                '  exit 0; ' +
                'fi; ' +
                'dir_all=$(fd --type d --hidden --one-file-system "${fd_excludes[@]}" -i "$query" "${valid[@]}" 2>/dev/null | sed \'s#/$##\'); ' +
                'dot_dirs=$(printf "%s\\n" "$dir_all" | grep -E "(^|/)\\.[^/]+$"); ' +
                'other_dirs=$(printf "%s\\n" "$dir_all" | grep -vE "(^|/)\\.[^/]+$"); ' +
                'if [ ${#fd_exts[@]} -gt 0 ]; then ' +
                '  file_all=$(fd --type f --hidden --one-file-system "${fd_excludes[@]}" "${fd_exts[@]}" -i "$query" "${valid[@]}" 2>/dev/null); ' +
                'else ' +
                '  file_all=$(fd --type f --hidden --one-file-system "${fd_excludes[@]}" -i "$query" "${valid[@]}" 2>/dev/null); ' +
                'fi; ' +
                '[ -n "$dot_dirs" ] && printf "%s\\n" "$dot_dirs" | sed "s/^/D\\t/"; ' +
                'if command -v fzf >/dev/null 2>&1; then ' +
                '  [ -n "$other_dirs" ] && printf "%s\\n" "$other_dirs" | fzf --filter="$query" | sed "s/^/D\\t/" | head -n 100; ' +
                '  [ -n "$file_all" ] && printf "%s\\n" "$file_all" | fzf --filter="$query" | sed "s/^/F\\t/" | head -n 200; ' +
                'else ' +
                '  [ -n "$other_dirs" ] && printf "%s\\n" "$other_dirs" | sed "s/^/D\\t/" | head -n 100; ' +
                '  [ -n "$file_all" ] && printf "%s\\n" "$file_all" | sed "s/^/F\\t/" | head -n 200; ' +
                'fi',
                "_",
                engine.query.trim()
            ];
            searchProc.running = true;
        }
    }

    Process {
        id: searchProc
        property int myGen: 0
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (searchProc.myGen !== engine.currentGeneration) return;
                const trimmed = line.trim();
                if (trimmed.length === 0) return;
                const tabIdx = trimmed.indexOf("\t");
                if (tabIdx < 0) return;
                const type = trimmed[0] === "D" ? "dir" : "file";
                const path = trimmed.slice(tabIdx + 1);
                if (engine.rawResults.length < engine.maxRawResults) {
                    engine.rawResults = [...engine.rawResults, { type, path }];
                }
            }
        }
    }
}
