---
description: Automatically force save all changes, commit to git, and push to Vercel.
---

1. **Force Save Verification**:
   - (Implicit) Ensure all `write_to_file` or `replace_file_content` operations are completed.

2. **Git Commit & Push**:
   - Run the following command to stage, commit, and push changes.
   // turbo
   ```bash
   git add . && git commit -m "Auto-save: Integrated updates" && git push
   ```

3. **Reporting**:
   - Notify the user that the "Save & Deploy" process has been initiated.
