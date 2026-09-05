# Local database dump

The EFRM dump is intentionally not stored in GitHub. It is 313,790,898 bytes,
exceeds GitHub's normal single-file limit, and may contain sensitive database
data.

Obtain the archive through an approved private channel and place it here:

```text
data\Kanji_011_20260903-133238.dump
```

Verify it before restoring:

```text
SHA-256: 731FDE9BE138AFC42AC3E41B64823DE18CAD1F5750BF0E509DA1BB0F86B774FC
```

Then run `src\local_postgres.py setup` from the repository root.

