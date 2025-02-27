import torch
import itertools

def expp(x, coefficient_fraction, constant_fraction, alpha, beta, gamma_1, gamma_2):
    sum_fraction = max(7, constant_fraction)

    gamma_1 = gamma_1 * 2 ** (sum_fraction - constant_fraction)
    gamma_2 = gamma_2 * 2 ** (sum_fraction - constant_fraction)

    mant_add = x.to(torch.int32) * 2 ** (sum_fraction - 7)
    res_add_1 = torch.where(mant_add < 2 ** (sum_fraction - 1), mant_add + gamma_1 , mant_add + gamma_2)

    mant_mul = x.to(torch.int32) * 2
    res_mul_1 = torch.where(mant_mul < 2 ** 7, mant_mul * alpha, (beta * (2 ** 8 - mant_mul - 1)))

    res_mul_2 = (res_mul_1.type(torch.int32) * res_add_1.type(torch.int32)) >> (sum_fraction + coefficient_fraction + 1)

    res = torch.where(mant_add < 2 ** (sum_fraction - 1), res_mul_2, 2 ** 7 - res_mul_2 - 1)

    return res

x = (torch.arange(0, 128, dtype = torch.int16) + (127 << 7)).view(torch.bfloat16)

baseline = x.exp2().view(torch.int16).bitwise_and(0x007F)

xh1 = torch.arange(0, 64, dtype = torch.int16)
xh2 = torch.arange(64, 128, dtype = torch.int16)

bh1 = baseline[0:64]
bh2 = baseline[64:128]

# Maximum allowed number of fractional bits for the alpha and beta constants
coeff_gran = 5

# Maximum allowed number of bits for the gamma_1 and gamma_2 constants
const_gran = 6

alpha_min = 0
alpha_max = 1

beta_min = 0
beta_max = 1

gamma_1_min = 2
gamma_1_max = 4

gamma_2_min = 2
gamma_2_max = 4

a = torch.arange(alpha_min * 2**coeff_gran, alpha_max * 2**coeff_gran, dtype=torch.int16)
b = torch.arange(beta_min * 2**coeff_gran, beta_max * 2**coeff_gran, dtype=torch.int16)
g1 = torch.arange(gamma_1_min * 2**const_gran, gamma_1_max * 2**const_gran, dtype=torch.int16)
g2 = torch.arange(gamma_2_min * 2**const_gran, gamma_2_max * 2**const_gran, dtype=torch.int16)

besth1   = []
biasesh1 = []

min_diffh1 = 64

for i in itertools.product(a,g1):
    res = expp(xh1, coeff_gran, const_gran, i[0], 0, i[1], 0)
    diff = (res != bh1).sum()
    bias = (res - bh1).sum()

    if diff < min_diffh1:
        besth1     = [i]
        min_diffh1 = diff
        biasesh1   = [bias]
    elif diff == min_diffh1:
        besth1.append(i)
        biasesh1.append(bias)

besth2   = []
biasesh2 = []

min_diffh2 = 64

for i in itertools.product(b,g2):
    res = expp(xh2, coeff_gran, const_gran, 0, i[0], 0, i[1])
    diff = (res != bh2).sum()
    bias = (res - bh2).sum()

    if diff < min_diffh2:
        besth2     = [i]
        min_diffh2 = diff
        biasesh2   = [bias]
    elif diff == min_diffh2:
        besth2.append(i)
        biasesh2.append(bias)

best1 = []
best2 = []

best_bias = 128

for i1 in range(len(besth1)):
    for i2 in range(len(besth2)):
        bias = (biasesh1[i1] + biasesh2[i2])

        if (bias.abs() < abs(best_bias)):
            best1     = besth1[i1]
            best2     = besth2[i2]
            best_bias = bias

print(f"Best parameters:")

print(f"ALPHA:\t\t{best1[0]}\t(x 2^{-coeff_gran})")
print(f"BETA:\t\t{best2[0]}\t(x 2^{-coeff_gran})")
print(f"GAMMA 1:\t{best1[1]}\t(x 2^{-const_gran})")
print(f"GAMMA 2:\t{best2[1]}\t(x 2^{-const_gran})")
print("\n")
print(f"BIAS:\t\t{best_bias}")
