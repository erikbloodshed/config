function fish_mode_prompt
    if test "$fish_key_bindings" != fish_default_key_bindings
        set --local vi_mode_color
        set --local vi_mode_symbol
        switch $fish_bind_mode
            case default
                set vi_mode_color (set_color red)
                set vi_mode_symbol '🅽 ' 
            case insert
                set vi_mode_color (set_color green)
                set vi_mode_symbol '🅸 '
            case replace replace_one
                set vi_mode_color (set_color yellow)
                set vi_mode_symbol '🆁 '
            case visual
                set vi_mode_color (set_color magenta)
                set vi_mode_symbol '🆅 '
        end
        echo -e "$vi_mode_color$vi_mode_symbol\x1b[0m "
    end
end
