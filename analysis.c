#include "analysis.h"
#include <math.h>

int spectrum_init(SpectrumAnalysis *a) {
    for (int i = 0; i < SPECTRUM_SIZE; ++i)
        a->window[i] = 0.5 - 0.5 * cos(2.0 * M_PI * i / (SPECTRUM_SIZE - 1));
    for (int b = 0; b <= SPECTRUM_BANDS; ++b) {
        double frequency = 45.0 * pow(10000.0 / 45.0, (double)b / SPECTRUM_BANDS);
        a->edges[b] = (int)ceil(frequency * SPECTRUM_SIZE / SPECTRUM_RATE);
    }
    a->plan = fftw_plan_dft_r2c_1d(SPECTRUM_SIZE, a->input, a->bins, FFTW_ESTIMATE);
    return a->plan != NULL;
}

void spectrum_levels(SpectrumAnalysis *a, const float *samples, double *levels) {
    for (int i = 0; i < SPECTRUM_SIZE; ++i)
        a->input[i] = samples[i] * a->window[i];
    fftw_execute(a->plan);
    for (int b = 0; b < SPECTRUM_BANDS; ++b) {
        double power = 0;
        for (int k = a->edges[b]; k < a->edges[b + 1]; ++k)
            power += a->bins[k][0] * a->bins[k][0] + a->bins[k][1] * a->bins[k][1];
        double amplitude = sqrt(power / (a->edges[b + 1] - a->edges[b])) * 4.0 / SPECTRUM_SIZE;
        double db = 20.0 * log10(fmax(amplitude, 1e-8));
        // A gentle treble tilt offsets the natural rolloff without auto-gain pumping.
        double tilt = 3.0 * b / (SPECTRUM_BANDS - 1);
        double level = fmin(1.0, fmax(0.0, (db + tilt + 68.0) / 52.0));
        // Smoothstep keeps quiet content quiet and leaves stronger transients distinct.
        levels[b] = level * level * (3.0 - 2.0 * level);
    }
}

void spectrum_destroy(SpectrumAnalysis *a) { fftw_destroy_plan(a->plan); }
