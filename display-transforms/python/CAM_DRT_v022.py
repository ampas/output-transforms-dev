import colour
import OpenImageIO as oiio
import numpy as np
import math



## path for incoming image
inputImagePath = '/Users/afry/Working/TestArea/ramp_XYZ.exr'

## read in image via openimageio
img = oiio.ImageBuf(inputImagePath)
spec = img.spec()
xres = spec.width
yres = spec.height
channels = spec.nchannels



hellwig2022vals = colour.appearance.hellwig2022.XYZ_to_Hellwig2022(img.get_pixels(),L_A=100.0,Y_b=20,XYZ_w=[95.05,100,108.88])
## tail track into JMh
JMh = colour.utilities.tstack([hellwig2022vals.J, hellwig2022vals.M, hellwig2022vals.h])

hellwig2022vals.J[32]

SAMPLES = np.linspace(0, 1, 65535)
ONES = colour.utilities.ones(SAMPLES.shape)
RGB = colour.utilities.tstack([SAMPLES, SAMPLES, ONES])
XYZ_AP0 = colour.RGB_to_XYZ(
    RGB * 100,
    colour.models.RGB_COLOURSPACE_ACES2065_1.whitepoint,
    colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D65'],
    colour.models.RGB_COLOURSPACE_ACES2065_1.matrix_RGB_to_XYZ,
)


illuminant_RGB = (0.31271, 0.32902)
illuminant_XYZ = (0.34567, 0.35850)
chromatic_adaptation_transform = 'Bradford'
RGB_to_XYZ_matrix = np.array([
    [0.41238656, 0.35759149, 0.18045049],
    [0.21263682, 0.71518298, 0.0721802],
    [0.01933062, 0.11919716, 0.95037259]])

XYZ_to_AP0_matrix = np.array([
    [1.0498110175,  0.0000000000, -0.0000974845],
    [-0.4959030231,  1.3733130458,  0.0982400361],
    [0.0000000000,  0.0000000000,  0.9912520182]])

## convert image to XYZ
imgXYZ = colour.RGB_to_XYZ(img.get_pixels(), illuminant_RGB, illuminant_XYZ, RGB_to_XYZ_matrix)

type(imgXYZ)

## oiio image from array
def oiioImageFromArray( imgArray, xres, yres, channels ):
    img = oiio.ImageBuf(oiio.ImageSpec(xres, yres, channels, oiio.UINT16))
    img.set_pixels(imgArray)
    return img


newImg = oiioImageFromArray(JMh.J, xres, yres, 1)

exrPath = '/Users/afry/Working/TestArea/test_004.exr'
# write out imgXYZ to exrPath
out = oiio.ImageOutput.create (exrPath)
spec = oiio.ImageSpec (xres, yres, channels, 'uint16')
out.open(exrPath, spec)
out.write_image(JMh)
out.close()



#   "PowerP" compression function (also used in the ACES Reference Gamut Compression transform)
#   values of v above  'treshold' are compressed by a 'power' function
#   so that an input value of 'limit' results in an output of 1.0
def compressPowerP( v:float, threshold:float, limit:float, power:float, inverse:int ):
    s = (limit-threshold)/pow(pow((1.0-threshold)/(limit-threshold),-power)-1.0,1.0/power)
    if inverse:
        vCompressed = v if (v<threshold or limit<1.0001 or v>threshold+s) else threshold+s*pow(-(pow((v-threshold)/s,power)/(pow((v-threshold)/s,power)-1.0)),1.0/power)
    else:
        vCompressed = v if (v<threshold or limit<1.0001) else threshold+s*((v-threshold)/s)/(pow(1.0+pow((v-threshold)/s,power),1.0/power))
    return vCompressed




def achromatic_response_forward(RGB:list):

    R = RGB.[0]
    G = RGB.[1]
    B = RGB.[2]

    A = 2 * R + G + 0.05 * B - 0.305
    return A

# may not actually be needed
def colourfulness_correlate(N_c:float, e_t:float, a:float, b:float): 
    float M = 43 * N_c * e_t * sqrt(pow(a,2) + pow(b,2))
    return M

# used by XYZ_to_Hellwig2022_JMh
def degree_of_adaptation(F:float,  L_A:float ):
    D = F * (1 - (1 / 3.6) * exp((-L_A - 42) / 92))
    return D

# convert radians to degrees
def degrees( radians:float ):
    return radians * 180.0 / math.pi

# convert degrees to radians
def radians( degrees:float ):
    return degrees / 180.0 * math.pi


