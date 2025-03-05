if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -U fish_greeting ""

set PATH $PATH $HOME/.local/bin
set PATH $PATH $HOME/.cargo/bin
set PATH $PATH $HOME/.local/bin/lua-language-server/bin

set -g fish_prompt_pwd_dir_length 0
set -g fish_vi_force_cursor 1
set -g fish_cursor_default block
set -g fish_cursor_insert line
set -g fish_cursor_replace_one underscore
set -g fish_cursor_visual block
