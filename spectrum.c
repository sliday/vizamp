#include "analysis.h"
#include <pulse/simple.h>
#include <pulse/error.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

int main(void) {
    const pa_sample_spec spec = { PA_SAMPLE_FLOAT32LE, SPECTRUM_RATE, 1 };
    const pa_buffer_attr attr = { UINT32_MAX, UINT32_MAX, UINT32_MAX, UINT32_MAX,
                                  SPECTRUM_HOP * sizeof(float) };
    int error = 0;
    pa_simple *audio = pa_simple_new(NULL, "Vizamp", PA_STREAM_RECORD,
        "@DEFAULT_MONITOR@", "Speaker spectrum", &spec, NULL, &attr, &error);
    if (!audio) { fprintf(stderr, "Audio monitor: %s\n", pa_strerror(error)); return 1; }
    SpectrumAnalysis analysis;
    if (!spectrum_init(&analysis)) { pa_simple_free(audio); return 1; }
    float samples[SPECTRUM_SIZE] = {0};
    double levels[SPECTRUM_BANDS];
    setvbuf(stdout, NULL, _IOLBF, 0);
    while (pa_simple_read(audio, samples + SPECTRUM_SIZE - SPECTRUM_HOP,
                          SPECTRUM_HOP * sizeof(float), &error) >= 0) {
        spectrum_levels(&analysis, samples, levels);
        for (int b = 0; b < SPECTRUM_BANDS; ++b)
            printf(b ? ";%.4f" : "%.4f", levels[b]);
        putchar('\n');
        if (ferror(stdout)) break;
        memmove(samples, samples + SPECTRUM_HOP,
                (SPECTRUM_SIZE - SPECTRUM_HOP) * sizeof(float));
    }
    if (!ferror(stdout) && error != 0)
        fprintf(stderr, "Audio monitor: %s\n", pa_strerror(error));
    spectrum_destroy(&analysis);
    pa_simple_free(audio);
    return error != 0;
}
