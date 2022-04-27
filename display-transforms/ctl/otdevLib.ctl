import "ACESlib.Transform_Common";


/* --- Tone scale math --- */

// The tone scale functions are derivative of python code written by Jed Smith
// that is licensed under an MIT license. Source is available at:
// 		<https://colab.research.google.com/drive/10C3HvDuoAhYad1qOG2r0v8fGR-5VdpO5>
// The following copyright notice is pasted from the original code:

/*
The MIT License

Copyright 2022 Jedediah Smith
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions: The above copyright notice and this
permission notice shall be included in all copies or substantial portions of the
Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

float contrast_lx( float in, float p, float v=0.18) {
	float x = clamp( in, 0, HALF_MAX);
	float s0 = pow( v, 1.-p);
	
	if (x < v) {
		return s0*pow(x, p);
    } else {
		return p*(x - v) + v;
    }	
}

float ts_mm( float x, float s0, float s1, float p) {
	return s1 * pow(x / (x + s0), p);
}

float flare( float in, float fl) {
	// flare compensation
	float x = clamp( in, 0, HALF_MAX);
	return x * x / (x + fl);
}
  
float tsm_mms_dc( float in, float Lp ) {

	// Tone scale parameters
	const float c0 = 1.2; // pre-tonemap contrast

	const float c1 = 1.1; // post-tonemap contrast
	const float su = 1.0; // surround compensation : 0.95=dim, 0.9=average

	const float p = c1 * su; // surround compensation, unconstrained

	// boost peak to clip : ~32@100nits, ~75~1000nits, 100@4000nits
	float w1 = pow(0.595*Lp/10000.0, 0.931) + 1.037;
	float s1 = w1*Lp/100.0; // scale y: 1@100nits, 40@4000nits

	const float ex = -0.26; // 0.18 -> 0.1 @ 100nits
	const float eb = 0.08; // exposure boost with > Lp
	float e0 = pow(2.0, ex + eb*log2(s1));
	float s0 = pow(s1/e0, 1.0/c1);

	const float fl = 0.01; // flare

	// Tone scale processing
	float x = contrast_lx( in, c0); // pivoted contrast scale
	x = ts_mm(x, s0, s1, p);
	x = flare(x, fl);

	return x;
}
/* --- End tone scale math --- */




// TODO: parameterize the CAT
const float D60_2_D65_CAT[3][3] = calculate_cat_matrix( AP0.white, REC709_PRI.white);



float[3] eotf( float linearCV[3], int EOTF = 1, bool LEGAL_RANGE = false) {
    // EOTF
    // 0: ST-2084 (PQ)
    // 1: BT.1886 (Rec.709/2020 settings)
    // 2: sRGB (mon_curve w/ presets)
    //    moncurve_r with gamma of 2.4 and offset of 0.055 matches the EOTF found in IEC 61966-2-1:1999 (sRGB)
    // 3: gamma 2.6
    // 4: linear (no EOTF)

	float outputCV[3];
    if (EOTF == 0) {  // ST-2084 (PQ)
		outputCV = Y_2_ST2084_f3( linearCV );        
    } else if (EOTF == 1) { // BT.1886 (Rec.709/2020 settings)
        outputCV = bt1886_r_f3( linearCV, 2.4, 1.0, 0.0);
    } else if (EOTF == 2) { // sRGB (mon_curve w/ presets)
        outputCV = moncurve_r_f3( linearCV, 2.4, 0.055);
    } else if (EOTF == 3) { // gamma 2.6
        outputCV = pow_f3( linearCV, 1./2.6);
    } else if (EOTF == 4) { // linear
        outputCV = linearCV;
    } 

    if (LEGAL_RANGE == true) {
        outputCV = fullRange_to_smpteRange_f3( outputCV);
    }
    
    return outputCV;
}


