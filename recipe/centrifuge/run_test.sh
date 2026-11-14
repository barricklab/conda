#!/bin/bash
# Index two random 20 kb "genomes" with a two-species taxonomy and classify 50 reads from each.
set -euxo pipefail

python - <<'EOF'
import random
random.seed(1)
g = {k: ''.join(random.choice('ACGT') for _ in range(20000)) for k in ('seqA', 'seqB')}
open('ref.fa', 'w').write(''.join(f'>{k}\n{v}\n' for k, v in g.items()))
with open('reads.fq', 'w') as f:
    for k, v in g.items():
        for i in range(50):
            p = random.randrange(0, len(v) - 100)
            f.write(f'@{k}_{i}\n{v[p:p+100]}\n+\n{"I" * 100}\n')
open('conv.txt', 'w').write('seqA\t101\nseqB\t102\n')
open('nodes.dmp', 'w').write('1\t|\t1\t|\tno rank\t|\n100\t|\t1\t|\tgenus\t|\n'
                             '101\t|\t100\t|\tspecies\t|\n102\t|\t100\t|\tspecies\t|\n')
open('names.dmp', 'w').write('1\t|\troot\t|\t\t|\tscientific name\t|\n'
                             '100\t|\tTestgenus\t|\t\t|\tscientific name\t|\n'
                             '101\t|\tTestgenus alpha\t|\t\t|\tscientific name\t|\n'
                             '102\t|\tTestgenus beta\t|\t\t|\tscientific name\t|\n')
EOF

centrifuge-build -p 2 --conversion-table conv.txt --taxonomy-tree nodes.dmp --name-table names.dmp ref.fa tiny
centrifuge -x tiny -U reads.fq -S out.tsv --report-file report.tsv -p 2
cat report.tsv

# every read must be assigned, uniquely, to the species it came from
n_ok=$(awk -F'\t' 'NR > 1 { split($1, a, "_"); if ((a[1] == "seqA" && $3 == 101) || (a[1] == "seqB" && $3 == 102)) n++ } END { print n + 0 }' out.tsv)
test "$n_ok" -eq 100
