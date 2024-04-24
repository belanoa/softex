# Copyright 2023 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Andrea Belano <andrea.belano@studio.unibo.it>
#

import numpy as np
import torch
import argparse

parser = argparse.ArgumentParser()

parser.add_argument("--fpformat"    ,   type = str,     default = "BFLOAT16"    )
parser.add_argument("--length"      ,   type = int,     default = 1024          )
parser.add_argument("--range"       ,   type = int,     default = 128           )
parser.add_argument("--monotonic"   ,   type = int,     default = 0             )
parser.add_argument("--step"        ,   type = int,     default = 1             )
parser.add_argument("--vectors"     ,   type = int,     default = 1             )

args = parser.parse_args()

fpformat    = args.fpformat
length      = args.length
range       = args.range
monotonic   = args.monotonic
step        = args.step
vectors     = args.vectors

match fpformat:
    case "BFLOAT16":
        dtype   = torch.bfloat16
        inttype = np.uint32
        width   = 2

final_scores_np     = np.empty(0, dtype = inttype)
final_baseline_np   = np.empty(0, dtype = inttype)
denominators        = []

for i in np.arange(0, vectors):
    if monotonic == 0:
        scores = torch.empty(length, dtype = dtype).uniform_(0, range)
    else:
        scores = torch.arange(0, length * step, step, dtype = dtype)

    scores_64 = scores.double()

    denominator = (scores_64 - scores_64.max()).exp().sum()

    denominators.append(denominator.item())

    baseline = (scores_64 - scores_64.max()).exp() /denominator

    if fpformat == "BFLOAT16":
        scores_np   = (np.frombuffer(scores.float().numpy(), np.uint32) >> 16).astype(inttype)
        baseline_np = (np.frombuffer(baseline.to(dtype).float().numpy(), np.uint32) >> 16).astype(inttype)
    else:
        scores_np   = np.frombuffer(scores.numpy(), inttype)
        baseline_np = np.frombuffer(baseline.to(dtype).numpy(), inttype)
    
    final_scores_np    = np.append(final_scores_np, scores_np)
    final_baseline_np  = np.append(final_baseline_np, baseline_np)

with open("sw/golden-model/scores.h", "w") as file:
    file.write("#ifndef __SFM_SCORES__\n")
    file.write("#define __SFM_SCORES__\n\n")

    file.write(f"#define LENGTH  {length}\n\n")

    file.write(f"#define FMT_WIDTH  {width}\n\n")

    file.write(f"#define N_VECTORS  {vectors}\n\n")
    
    file.write("#define SCORES {    \\\n")

    for i in final_scores_np:
        file.write(f"   0x{i:x},    \\\n")

    file.write("}\n\n")

    file.write("#endif")

with open("sw/golden-model/golden.h", "w") as file:
    file.write("#ifndef __SFM_GOLDEN__\n")
    file.write("#define __SFM_GOLDEN__\n\n")
    
    file.write("#define GOLDEN {    \\\n")

    for i in final_baseline_np:
        file.write(f"   0x{i:x},    \\\n")

    file.write("}\n\n")

    file.write("#endif")

with open("golden-model/golden_sum.txt", "w") as file:
    for i in denominators:
        file.write(f"{i}\n")

with open("golden-model/golden.txt", "w") as file:
    for i in final_baseline_np:
        file.write(f"{i}\n")