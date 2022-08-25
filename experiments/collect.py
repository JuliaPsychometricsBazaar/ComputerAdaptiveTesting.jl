import json
import sys
from glob import glob


def iter_results():
    for fn in glob(sys.argv[1] + "/*.jsonl"):
        with open(fn) as f:
            for line in f:
                row = json.loads(line)
                if "result" in row:
                    row.update(row["result"])
                    del row["result"]
                yield row

cols = set()
for result in iter_results():
    cols.update(result.keys())

with open(sys.argv[2], "w") as fout:
    fout.write(",".join(cols))
    fout.write("\n")
    for result in iter_results():
        started = False
        for col in cols:
            if started:
                fout.write(",")
            if col in result:
                fout.write('"{}"'.format(str(result[col]).replace('"', r'\"')))
            started = True
        fout.write("\n")