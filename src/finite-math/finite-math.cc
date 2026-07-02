#include <math.h>
#include <immintrin.h>

// This workaround provides some missing "finite" version of math functions,
// which have been removed from the higher version of glibc math library.
//
// They are implemented by routing calls to their "non-finite" counterparts

extern "C" {
  double __exp2_finite(double x) { return exp2(x); }
  double __exp_finite(double x) { return exp(x); }
  double __log_finite(double x) { return log(x); }
  double __log2_finite(double x) { return log2(x); }
  double __log10_finite(double x) { return log10(x); }
  double __pow_finite(double x, double y) { return pow(x, y); }
  double __acos_finite(double x) { return acos(x); }
  double __atan2_finite(double y, double x) { return atan2(y, x); }

  float __exp2f_finite(float x) { return exp2f(x); }
  float __expf_finite(float x) { return expf(x); }
  float __logf_finite(float x) { return logf(x); }
  float __log2f_finite(float x) { return log2f(x); }
  float __log10f_finite(float x) { return log10f(x); }
  float __powf_finite(float x, float y) { return powf(x, y); }
  float __acosf_finite(float x) { return acosf(x); }
  float __atan2f_finite(float y, float x) { return atan2f(y, x); }

  // Vectorised version of log()
  extern __m128d  _ZGVbN2v_log(__m128d);
  __m128d _ZGVbN2v___log_finite (__m128d x) {
    return _ZGVbN2v_log(x);
  }

}
