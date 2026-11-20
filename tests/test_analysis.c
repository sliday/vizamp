#include "analysis.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>

static int strongest(const double *values) {
    int best = 0;
    for (int i = 1; i < SPECTRUM_BANDS; ++i) if (values[i] > values[best]) best = i;
    return best;
}

int main(void) {
    SpectrumAnalysis a;
    assert(spectrum_init(&a));
    for (int i = 0; i < SPECTRUM_BANDS; ++i) assert(a.edges[i + 1] > a.edges[i]);
    float samples[SPECTRUM_SIZE] = {0};
    double values[SPECTRUM_BANDS];
    spectrum_levels(&a, samples, values);
    for (int i = 0; i < SPECTRUM_BANDS; ++i) assert(values[i] == 0);
    const double frequencies[] = {100, 500, 2000, 6500};
    int previous = -1;
    for (int f = 0; f < 4; ++f) {
        for (int i = 0; i < SPECTRUM_SIZE; ++i)
            samples[i] = 0.4 * sin(2 * M_PI * frequencies[f] * i / SPECTRUM_RATE);
        spectrum_levels(&a, samples, values);
        int best = strongest(values);
        assert(best > previous);
        assert(values[best] > 0.45);
        previous = best;
        for (int i = 0; i < SPECTRUM_BANDS; ++i) assert(isfinite(values[i]) && values[i] >= 0 && values[i] <= 1);
        double loud = values[best];
        for (int i = 0; i < SPECTRUM_SIZE; ++i) samples[i] *= 0.1;
        spectrum_levels(&a, samples, values);
        assert(values[best] < loud);
    }
    spectrum_destroy(&a);
    puts("DSP: distinct frequency bands, silence, level response and bounds passed");
}
