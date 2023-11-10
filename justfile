# Repo Browser Tasks

set shell := ["nu", "-c"]

default:
  @just --list --list-heading "Development Tasks\r\n" --list-prefix "> "
