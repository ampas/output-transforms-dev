import "otdevLib";




int[3] order3( float r, float g, float b)
{  
  // Determine sort order, highest to lowest
   if (r > g) {
      if (g > b) {                    // r g b, hue [0,60]
         int order[3] = {0, 1, 2};
         return order;
      } else {
         if (r > b) {                 // r b g, hue [300,360]
            int order[3] = {0, 2, 1};
            return order;
         } else {                     // b r g, hue [240,300]
            int order[3] = {2, 0, 1};
            return order;
         }
      }
   }
   else {
      if (r > b) {                    // g r b, hue [60,120]
         int order[3] = {1, 0, 2};
         return order;
      } else {
         if (g > b) {                 // g b r, hue [120,180]
            int order[3] = {1, 2, 0};
            return order;
         } else {                     // b g r, hue [180,240]
            int order[3] = {2, 1, 0};
            return order;
         }
      }
   }
}

// Modify the hue of post_tone to match pre_tone
float[3] restore_hue_dw3( float pre_tone[3], float post_tone[3])
{
   int inds[3] = order3( pre_tone[0], pre_tone[1], pre_tone[2]);

   float orig_chroma = pre_tone[ inds[0]] - pre_tone[ inds[2]]; 

   float hue_factor = ( pre_tone[ inds[1] ] - pre_tone[ inds[2] ]) / orig_chroma;

   if ( orig_chroma == 0.) hue_factor = 0.;

   float new_chroma = post_tone[ inds[0] ] - post_tone[ inds[2] ];

   float out[3];
   out[ inds[ 0] ] = post_tone[ inds[0] ];
   out[ inds[ 1] ] = hue_factor * new_chroma + post_tone[ inds[2] ];
   out[ inds[ 2] ] = post_tone[ inds[2] ];

   return out;
}


const Chromaticities RENDERING_PRI = 
{
	{0.8058, 0.2975},
	{-0.0413, 1.1193},
	{0.0503, -0.0744},
	{0.3217, 0.3377}
};

const float XYZ_2_RENDERING_PRI_MAT[4][4] = XYZtoRGB(RENDERING_PRI, 1.0);
const float RENDERING_PRI_2_XYZ_MAT[4][4] = RGBtoXYZ(RENDERING_PRI, 1.0);
const float AP0_2_RENDERING_PRI_MAT[4][4] = mult_f44_f44( AP0_2_XYZ_MAT, XYZ_2_RENDERING_PRI_MAT);


const Chromaticities DISPLAY_PRI = REC709_PRI;
const float XYZ_2_DISPLAY_PRI_MAT[4][4] = XYZtoRGB(DISPLAY_PRI,1.0);


// Might be useful later to adjust path-to-white

// float determine_inv_sat( float rgb[3], float norm )
// {
//     float min_chan = min( min( rgb[0], rgb[1]), rgb[2]);
//     float max_chan = max( max( rgb[0], rgb[1]), rgb[2]);
// 
//     // When norm = mx, inv_sat = mn / mx.
//     float inv_sat = 1.0 - ( max_chan - min_chan) / max( norm, 1e-8);
// 
//     // This is near 0 for saturated colors and 1 for neutrals.
//     return inv_sat;
// }


// Switches to test the effect or non-effect of various choices made in the rendering steps
const bool restoreVsOriginal = true;
const bool useSmartClip = false;



void main ( 
	input varying float rIn,
	input varying float gIn,
	input varying float bIn,
	input varying float aIn,
	output varying float rOut,
	output varying float gOut,
	output varying float bOut,
	output varying float aOut,
	input varying float Lp = 100.
) 
{
	// Put input variables into a 3-element array (ACES)
	float aces[3] = {rIn, gIn, bIn};

	// Convert from ACES RGB encoding to rendering primaries RGB encoding
	float rgbPre[3] = mult_f3_f44( aces, AP0_2_RENDERING_PRI_MAT);

	float rgbPre_clamped[3] = clamp_f3( rgbPre, 0.0, HALF_MAX);

	// Apply the tone scale
	float rgbPost[3];
	rgbPost[0] = tsm_mms_dc( rgbPre_clamped[0], Lp);
	rgbPost[1] = tsm_mms_dc( rgbPre_clamped[1], Lp);
	rgbPost[2] = tsm_mms_dc( rgbPre_clamped[2], Lp);

	// Switch to see if there is any effect of doing the ratio-restore based on the
	// pre-clamped or clamped RGB input.
	if (restoreVsOriginal) { // Restore the hue to the pre-tonescale hue
		rgbPost = restore_hue_dw3( rgbPre, rgbPost);
	} else { // otherwise, restore using the RGB rendering space values clamped
	  	// Restore the hue to the pre-tonescale hue
		rgbPost = restore_hue_dw3( rgbPre_clamped, rgbPost);	  
	}

	// --- ODT ---
	// Convert from rendering primaries RGB encoding to display encoding primaries
	float XYZ[3] = mult_f3_f44( rgbPost, invert_f44(XYZ_2_RENDERING_PRI_MAT));

	// Apply CAT from ACES white point to assumed observer adapted white point
	XYZ = mult_f3_f33( XYZ, D60_2_D65_CAT);

	// CIE XYZ to display primaries
	float lin_displayRGB[3] = mult_f3_f44( XYZ, XYZ_2_DISPLAY_PRI_MAT);

	float lin_displayRGB_clamped[3] = clamp_f3( lin_displayRGB, 0.0, 1.0);
	// This is a useful toggle to see impact on how saturated OOG values clamp to the 
	// display gamut boundary triangle.
	if (useSmartClip) {
		lin_displayRGB = restore_hue_dw3( lin_displayRGB, lin_displayRGB_clamped); 
	} else {
		lin_displayRGB = lin_displayRGB_clamped;
	}

	// Inverse EOTF for display
	float out[3] = eotf( lin_displayRGB );

	// Assign dispaly RGB to output variables (OCES)
	rOut = out[0];
	gOut = out[1];
	bOut = out[2];
	aOut = aIn;

}