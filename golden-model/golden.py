import numpy as np
import torch
import argparse

parser = argparse.ArgumentParser()

parser.add_argument("--fpformat"    ,   type = str,     default = "BFLOAT16"    )
parser.add_argument("--length"      ,   type = int,     default = 1024          )
parser.add_argument("--range"       ,   type = int,     default = 128           )

args = parser.parse_args()

fpformat    = args.fpformat
length      = args.length
range       = args.range

match fpformat:
    case "BFLOAT16":
        dtype = torch.bfloat16
        width = 2

scores = torch.empty(length, dtype = dtype).uniform_(0, range)
#scores = torch.arange(0, length, 1, dtype = dtype)
scores_64 = scores.double()

baseline = (scores_64 - scores_64.max()).exp() / (scores_64 - scores_64.max()).exp().sum()

if fpformat == "BFLOAT16":
    scores_np   = (np.frombuffer(scores.float().numpy(), np.uint32) >> 16).astype(np.uint16)
    baseline_np = (np.frombuffer(baseline.to(dtype).float().numpy(), np.uint32) >> 16).astype(np.uint16)
else:
    scores_np   = np.frombuffer(scores.numpy(), inttype)
    baseline_np = np.frombuffer(baseline.to(dtype).numpy(), inttype)



with open("sw/golden-model/scores.h", "w") as file:
    file.write("#ifndef __SFM_SCORES__\n")
    file.write("#define __SFM_SCORES__\n\n")

    file.write(f"#define LENGTH  {length}\n\n")

    file.write(f"#define FMT_WIDTH  {width}\n\n")
    
    file.write("#define SCORES {    \\\n")

    for i in scores_np:
        file.write(f"   0x{i:x},    \\\n")

    file.write("}\n\n")

    file.write("#endif")

with open("sw/golden-model/golden.h", "w") as file:
    file.write("#ifndef __SFM_GOLDEN__\n")
    file.write("#define __SFM_GOLDEN__\n\n")
    
    file.write("#define GOLDEN {    \\\n")

    for i in baseline_np:
        file.write(f"   0x{i:x},    \\\n")

    file.write("}\n\n")

    file.write("#endif")

with open("golden-model/golden_sum.txt", "w") as file:
    file.write(f"{(scores_64 - scores_64.max()).exp().sum().item()}")

with open("golden-model/golden.txt", "w") as file:
    for i in baseline_np:
        file.write(f"{i}\n")