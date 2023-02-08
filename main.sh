#!/bin/bash

USER=$(whoami)
NGROK_TOKEN="2KtRkhcqvGb9pHLTIlm35oPjzf2_4bLwDzDfPeEEuMaVGBtmW"
SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCiojx5UtkvDFKibcEFVpR2UABTQogjoSB9DnGHHSl0/SLrHkb5ncZU95UFkvpj5IjvGjZ12oNGEW9rLKjZTERTu/0ZzabSieLeYEjyX4h6MM7eRybr/Zk71WfFJ66wjxhVXcmilorTBqDSxJSLoqqQY85CjqTZ6Eq3kVUsKBfxg3Tiv9br7rxg0Zg8fekJ/GQT4zgA2uckK/UlrEmRkwVrI87q3fX+KfEpLbkWCZiHGYkOr8SHZ+RSqXc+d322O4FuGEbc6FRtgCrZG2bfYadEe3a0nKv4uvYNF+SzShbhkCMu5Cos8zCAWNrLk8hh1fdsAyNu78DjVM3MK1EpBslx rsa-key-20230126"
if [[ -z "$NGROK_TOKEN" ]]; then
  echo "Please set 'NGROK_TOKEN'"
  exit 1
fi

echo "### Prep for remote login and install ngrok ###"

case $(uname) in
    Darwin)
        PKG="https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-darwin-amd64.zip"
        ;;
    Linux)
        # By default, the Actions runner user lacks a .ssh directory and also
        # has a home directory with permissions 777, and sshd will refuse to
        # allow an incoming connection in that state.
        chmod 755 "$HOME"
        mkdir "$HOME"/.ssh
        PKG="https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip"
        ;;
    *_NT-*)
        # I wasn't able to get remote login working on Windows using the public key
        # approach we do below on macOS/Linux, so we settle for having to enter a
        # password.
        if [[ -z "$USER_PASS" ]]; then
            echo "Please set 'USER_PASS' for user: $USER"
            exit 1
        fi
        net user "$USER" "$USER_PASS"
        PKG="https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-windows-amd64.zip"
        exe=.exe
        ;;
esac

if [[ $(uname) = "Darwin" || $(uname) = "Linux" ]]; then
    # Install a public key so we can login via SSH without a password.
    if [[ -z "$SSH_PUBLIC_KEY" ]]; then
        echo "Please set 'SSH_PUBLIC_KEY'"
        exit 1
    fi
    chmod 700 "$HOME"/.ssh
    echo "$SSH_PUBLIC_KEY" >> "$HOME"/.ssh/authorized_keys
    chmod 600 "$HOME"/.ssh/authorized_keys
    IDENTITY="-i ~\/.ssh\/ngrok"
fi

curl -o ngrok.zip "$PKG"
unzip -o ngrok.zip

echo "### Start ngrok proxy for 22 port ###"

rm -f .ngrok.log
./ngrok$exe authtoken "$NGROK_TOKEN"
./ngrok$exe tcp 22 --log ".ngrok.log" &

sleep 10
HAS_ERRORS=$(grep "command failed" < .ngrok.log)

if [[ -z "$HAS_ERRORS" ]]; then
  echo ""
  echo "=========================================="
  echo "To connect: $(grep -o -E "tcp://(.+)" < .ngrok.log | sed "s/tcp:\/\//ssh $IDENTITY $USER@/" | sed "s/:/ -p /")"
  echo "=========================================="
else
  echo "$HAS_ERRORS"
  exit 4
fi
