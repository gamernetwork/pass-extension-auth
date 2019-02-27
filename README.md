# pass-extension-auth

manage pass access control

Requires a recent version of pass that supports extensions, use 1.7.3 or later. Thia may require using the git repo version instead of your OS pkg as the latter will most likely be out of date.

    mkdir ~/.password-store/.extensions
    cp auth.bash ~/.password-store/.extensions
    chmod 755 ~/.password-store/.extensions/auth.bash

set an env variable

    PASSWORD_STORE_ENABLE_EXTENSIONS=true

or add it to an alias that calls pass

## Usage

Display users that can view and edit an entry:

    pass auth path/to/key

To add or remove users from an entry:

    pass auth path/to/key [add|rm] <gpg_id>
