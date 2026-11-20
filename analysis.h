#ifndef MENUBAR_SPECTRUM_ANALYSIS_H
#define MENUBAR_SPECTRUM_ANALYSIS_H
#include <fftw3.h>
#define SPECTRUM_SIZE 2048
#define SPECTRUM_HOP 512
#define SPECTRUM_BANDS 24
#define SPECTRUM_RATE 24000

typedef struct {
    double input[SPECTRUM_SIZE];
    double window[SPECTRUM_SIZE];
    fftw_complex bins[SPECTRUM_SIZE / 2 + 1];
    int edges[SPECTRUM_BANDS + 1];
    fftw_plan plan;
} SpectrumAnalysis;

int spectrum_init(SpectrumAnalysis *analysis);
void spectrum_levels(SpectrumAnalysis *analysis, const float *samples, double *levels);
void spectrum_destroy(SpectrumAnalysis *analysis);
#endif
