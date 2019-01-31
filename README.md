# pass-extension-auth

manage pass access control

    mkdir ~/.password-store/.extensions
    cp auth.bash ~/.password-store/.extensions
    chmod 755 ~/.password-store/.extensions/auth.bash

set an env variable

    PASSWORD_STORE_ENABLE_EXTENSIONS=true

or add it to an alias that calls pass
