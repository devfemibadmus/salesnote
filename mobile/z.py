
import os
import shutil

base = r"C:\Users\Femi.Badmus\.gradle\caches\8.14\transforms" #change to ur gradle path

for name in os.listdir(base):
    if "-" in name:
        src = os.path.join(base, name)
        dst = os.path.join(base, name.split("-", 1)[0])
        if os.path.isdir(src):
            if os.path.exists(dst):
                shutil.rmtree(dst)
                print(f"Deleted: {dst}")
            print(f"Renaming: {src} -> {dst}")
            os.rename(src, dst)
