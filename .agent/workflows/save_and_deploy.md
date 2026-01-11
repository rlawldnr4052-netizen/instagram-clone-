---
description: Automatically force save all changes, build for web, commit, and push to Vercel.
---

1. **Force Save Verification**:
   - (Implicit) Ensure all changes are saved.

2. **Build Web Release**:
   - Run the Flutter build command to generate static files.
   // turbo
   ```bash
   flutter build web --release
   ```

3. **Git Commit & Push**:
   - Stage everything (including the new build), commit, and push.
   // turbo
   ```bash
   git add . && git commit -m "Auto-deploy: Built and pushed latest changes" && git push
   ```

4. **Reporting**:
   - Notify the user that the process is complete.
