#!/bin/sh
set -eu

main() {
    BASE_URL="https://raw.githubusercontent.com/g0nd1/bashing/main"
    BIN_DIR="$HOME/.local/bin"
    LIB_DIR="$HOME/.local/lib/bash"
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
    ENV_FILE="$CONFIG_DIR/flyline-ai.env"
    export PATH="$HOME/.cargo/bin:$PATH"

    if ! command -v cargo >/dev/null 2>&1; then
        ID=unknown; ID_LIKE=''
        if [ -r /etc/os-release ]; then . /etc/os-release; fi
        case " $ID $ID_LIKE " in
            *fedora*|*rhel*|*centos*) cmd='sudo dnf install cargo rust gcc git jq' ;;
            *debian*|*ubuntu*) cmd='sudo apt install cargo rustc build-essential git jq' ;;
            *arch*) cmd='sudo pacman -S --needed rust base-devel git jq' ;;
            *suse*) cmd='sudo zypper install cargo rust gcc git jq' ;;
            *alpine*) cmd='sudo apk add cargo rust build-base git jq' ;;
            *) cmd='https://rustup.rs/' ;;
        esac
        printf 'Cargo fehlt. Bitte zuerst installieren:\n  %s\nDanach dieses Skript erneut ausführen.\n' "$cmd"
        exit 1
    fi
    for tool in git curl bash jq; do
        command -v "$tool" >/dev/null 2>&1 || { printf '%s fehlt. Bitte installieren.\n' "$tool" >&2; exit 1; }
    done
    [ "$(id -u)" -ne 0 ] || { echo 'Bitte ohne sudo ausführen.' >&2; exit 1; }
    exec 3</dev/tty 4>/dev/tty
    umask 077
    TMP=$(mktemp -d)
    TTY_STATE=''
    trap 'if [ -n "$TTY_STATE" ]; then stty "$TTY_STATE" <&3; fi; rm -rf "$TMP"' 0
    trap 'exit 1' HUP INT TERM

    echo '[1/4] Flyline kompilieren ...'
    git clone --depth 1 https://github.com/HalFrgrd/flyline.git "$TMP/flyline"
    (cd "$TMP/flyline" && cargo build --release --locked)

    echo '[2/4] Dateien herunterladen ...'
    for file in .bashrc-extend flyline-git-branch flyline-openai; do
        curl -fsSL "$BASE_URL/$file" -o "$TMP/$file"
        bash -n "$TMP/$file"
    done

    echo '[3/4] KI-Konfiguration ...'
    if [ -f "$ENV_FILE" ]; then
        printf 'Vorhandene KI-Konfiguration ersetzen? [j/N] ' >&4
        IFS= read -r answer <&3
    else
        answer=j
    fi
    case "$answer" in
        j|J|ja|JA)
            printf 'FLYLINE_AI_BASE_URL: ' >&4
            IFS= read -r ai_url <&3
            printf 'FLYLINE_AI_API_KEY: ' >&4
            TTY_STATE=$(stty -g <&3)
            stty -echo <&3
            IFS= read -r ai_key <&3
            stty "$TTY_STATE" <&3
            TTY_STATE=''
            select_ai_model
            {
                env_line FLYLINE_AI_BASE_URL "$ai_url"
                env_line FLYLINE_AI_API_KEY "$ai_key"
                env_line FLYLINE_AI_MODEL "$ai_model"
            } > "$TMP/flyline-ai.env"
            unset ai_key
            ;;
    esac

    echo '[4/4] Installation ...'
    mkdir -p "$BIN_DIR" "$LIB_DIR" "$CONFIG_DIR"
    install -m 644 "$TMP/flyline/target/release/libflyline.so" "$LIB_DIR/libflyline.so"
    install -m 644 "$TMP/.bashrc-extend" "$HOME/.bashrc-extend"
    install -m 755 "$TMP/flyline-git-branch" "$TMP/flyline-openai" "$BIN_DIR/"
    if [ -f "$TMP/flyline-ai.env" ]; then
        install -m 600 "$TMP/flyline-ai.env" "$ENV_FILE"
    fi
    chmod 600 "$ENV_FILE"
    touch "$HOME/.bashrc"
    marker='# BEGIN FLYLINE EXTENSION'
    if ! grep -Fxq "$marker" "$HOME/.bashrc"; then
        cat >> "$HOME/.bashrc" <<'BASHRC'

# BEGIN FLYLINE EXTENSION
if [ -f "$HOME/.bashrc-extend" ]; then
    . "$HOME/.bashrc-extend"
fi
# END FLYLINE EXTENSION
BASHRC
    fi


    echo '[5/5] Nerd Font installieren ...'
    FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/NotoNerdFont"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Noto.tar.xz"

    if ! command -v fc-cache >/dev/null 2>&1 ||
    ! command -v xz >/dev/null 2>&1; then

        echo 'Warnung: fontconfig oder xz fehlt. Schriftinstallation übersprungen.'

    elif [ -f "$FONT_DIR/.installed" ]; then

        echo 'Noto Nerd Font ist bereits installiert.'

    else
        mkdir -p "$FONT_DIR"

        if curl -fsSL \
            --connect-timeout 10 \
            --max-time 180 \
            "$FONT_URL" -o "$TMP/Noto.tar.xz" &&
            tar -xJf "$TMP/Noto.tar.xz" -C "$FONT_DIR" &&
            fc-cache -f "$FONT_DIR"; then

            touch "$FONT_DIR/.installed"
            echo 'Noto Nerd Font erfolgreich installiert.'

        else
            echo 'Warnung: Schriftinstallation fehlgeschlagen.' >&2
        fi
    fi

    printf '\nInstallation abgeschlossen.\nNeue Bash öffnen oder: source ~/.bashrc\n'
}

env_line() {
    # Shell-sichere Quotierung, auch bei Apostrophen und Sonderzeichen.
    escaped=$(printf '%s' "$2" | sed "s/'/'\\\\''/g")
    printf "export %s='%s'\n" "$1" "$escaped"
}

select_ai_model() {
    models_url="${ai_url%/}/models"

    printf '\nVerfügbare KI-Modelle werden abgerufen ...\n' >&4

    if curl -fsS \
        --connect-timeout 10 \
        --max-time 30 \
        -H "Authorization: Bearer $ai_key" \
        -H "Accept: application/json" \
        "$models_url" \
        -o "$TMP/models.json" &&
        jq -r '
            [.data[].id
                | select(type == "string" and length > 0)
                | select(test("[[:cntrl:]]") | not)]
            | unique
            | sort
            | .[]
        ' "$TMP/models.json" > "$TMP/models.txt" &&
        [ -s "$TMP/models.txt" ]; then

        model_count=$(wc -l < "$TMP/models.txt" | tr -d ' ')

        printf '\nVerfügbare KI-Modelle:\n\n' >&4
        nl -w3 -s') ' "$TMP/models.txt" >&4
        printf '\n  0) Modell manuell eingeben\n\n' >&4

        while :; do
            printf 'Modell auswählen [0-%s]: ' "$model_count" >&4
            IFS= read -r choice <&3

            case "$choice" in
                0)
                    break
                    ;;
                ''|*[!0-9]*)
                    printf 'Ungültige Eingabe.\n' >&4
                    continue
                    ;;
            esac

            if [ "$choice" -ge 1 ] 2>/dev/null &&
               [ "$choice" -le "$model_count" ] 2>/dev/null; then

                ai_model=$(sed -n "${choice}p" "$TMP/models.txt")

                printf 'Ausgewähltes Modell: %s\n' "$ai_model" >&4
                return 0
            fi

            printf 'Ungültige Auswahl.\n' >&4
        done
    else
        printf '\nDie Modellliste konnte nicht geladen werden.\n' >&4
        printf 'Bitte das gewünschte Modell manuell eingeben.\n' >&4
    fi

    while :; do
        printf 'FLYLINE_AI_MODEL: ' >&4
        IFS= read -r ai_model <&3
        [ -n "$ai_model" ] && break
        printf 'Die Modell-ID darf nicht leer sein.\n' >&4
    done
}

main "$@"
