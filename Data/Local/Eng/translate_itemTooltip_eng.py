import re
import time
from deep_translator import GoogleTranslator

translator = GoogleTranslator(source='vi', target='en')

print("Loading file...")

with open('itemTooltip_eng.txt', 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f"Loaded {len(lines)} lines")

cache = {}
translated_count = 0
start_time = time.time()

for i, line in enumerate(lines):

    m = re.search(r'"([^"]+)"', line)
    if not m:
        continue

    text = m.group(1)

    if text not in cache:

        translated_count += 1

        print(
            f"[{translated_count}] Translating: {text}",
            flush=True
        )

        try:
            translated = translator.translate(text)

            cache[text] = translated

            print(
                f"    -> {translated}",
                flush=True
            )

        except Exception as e:

            cache[text] = text

            print(
                f"    ERROR: {e}",
                flush=True
            )

        # промежуточная статистика
        if translated_count % 50 == 0:

            elapsed = time.time() - start_time

            print(
                f"\n=== Progress ===\n"
                f"Unique translated: {translated_count}\n"
                f"Elapsed: {elapsed:.1f}s\n",
                flush=True
            )

    lines[i] = line.replace(
        f'"{text}"',
        f'"{cache[text]}"'
    )

print("\nWriting output file...")

with open(
    'itemTooltip_translated.txt',
    'w',
    encoding='utf-8'
) as f:
    f.writelines(lines)

elapsed = time.time() - start_time

print(
    f"\nDone!\n"
    f"Unique names translated: {len(cache)}\n"
    f"Time: {elapsed:.1f} sec"
)