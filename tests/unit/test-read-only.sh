#!/bin/sh

set -eu

binary=$1
library=$(pkg-config --variable=libdir libgit2-glib-1.0)/libgit2-glib-1.0.so.0

command -v nm >/dev/null || { echo "FAIL: nm is not installed" >&2; exit 1; }
[ -f "$library" ] || { echo "FAIL: $library not found" >&2; exit 1; }

writers="
ggit_branch_delete
ggit_branch_move
ggit_branch_set_upstream
ggit_commit_amend
ggit_config_delete_entry
ggit_config_set_bool
ggit_config_set_int32
ggit_config_set_int64
ggit_config_set_string
ggit_index_add
ggit_index_add_file
ggit_index_add_path
ggit_index_remove
ggit_index_write
ggit_index_write_tree
ggit_index_write_tree_to
ggit_rebase_abort
ggit_rebase_commit
ggit_rebase_finish
ggit_rebase_next
ggit_ref_delete
ggit_ref_delete_log
ggit_ref_rename
ggit_ref_set_symbolic_target
ggit_ref_set_target
ggit_reflog_append
ggit_reflog_rename
ggit_reflog_write
ggit_remote_download
ggit_remote_prune
ggit_remote_push
ggit_remote_update_tips
ggit_remote_upload
ggit_repository_add_remote_fetch
ggit_repository_add_remote_push
ggit_repository_checkout_head
ggit_repository_checkout_index
ggit_repository_checkout_tree
ggit_repository_cherry_pick
ggit_repository_cherry_pick_commit
ggit_repository_clone
ggit_repository_create_blob
ggit_repository_create_blob_from_buffer
ggit_repository_create_blob_from_file
ggit_repository_create_blob_from_path
ggit_repository_create_branch
ggit_repository_create_commit
ggit_repository_create_commit_from_ids
ggit_repository_create_commit_with_signature
ggit_repository_create_note
ggit_repository_create_reference
ggit_repository_create_remote
ggit_repository_create_symbolic_reference
ggit_repository_create_tag
ggit_repository_create_tag_annotation
ggit_repository_create_tag_from_buffer
ggit_repository_create_tag_lightweight
ggit_repository_delete_tag
ggit_repository_drop_stash
ggit_repository_init_repository
ggit_repository_merge
ggit_repository_rebase_init
ggit_repository_remove_note
ggit_repository_remove_remote
ggit_repository_rename_remote
ggit_repository_reset
ggit_repository_reset_default
ggit_repository_revert
ggit_repository_save_stash
ggit_repository_set_head
ggit_repository_set_head_detached
ggit_repository_set_remote_url
ggit_repository_set_submodule_fetch_recurse
ggit_repository_set_submodule_ignore
ggit_repository_set_submodule_update
ggit_repository_set_submodule_url
ggit_repository_set_workdir
ggit_submodule_init
ggit_submodule_sync
ggit_submodule_update
ggit_tree_builder_write
"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

nm -D --defined-only "$library" | awk '{ print $NF }' | sort -u > "$tmp/exported"
nm -D --undefined-only "$binary" | awk '{ print $NF }' | sort -u > "$tmp/imported"
echo "$writers" | sed '/^$/d' | sort -u > "$tmp/writers"

unknown=$(comm -23 "$tmp/writers" "$tmp/exported")
found=$(comm -12 "$tmp/writers" "$tmp/imported")
status=0

if [ -n "$unknown" ]; then
	echo "FAIL: not exported by $library:" >&2
	echo "$unknown" | sed 's/^/  /' >&2
	status=1
fi

if [ -n "$found" ]; then
	echo "FAIL: $binary imports functions that write to a repository:" >&2
	echo "$found" | sed 's/^/  /' >&2
	status=1
fi

[ $status -eq 0 ] && echo "no writing function imported: $(wc -l < "$tmp/writers") checked, $(grep -c '^ggit_' "$tmp/imported") ggit functions imported"
exit $status
