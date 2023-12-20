

## based on this desmos plot https://www.desmos.com/calculator/pcsovzirqa

# Example usage:
c = 75
yc = 60
xc = 70
m = 0.0

f = 1 # Fudge factor (to get approximation closer to curve)
# mf = m * f  # Replace with your value
g1 = 1.15  # Lower Gamma
g2 = 1.273  # Upper Gamma


def findCurveIntersection(c,yc,xc,m,g1,g2):
    f = 1.0
    mf = m * f
    if not m*xc + c < yc:
        # above cusp
        # xi  = (1+mf) ** ((g2-1)) * (xc * (100 - yc) * ((100-c)/(100-yc)) ** (1/g2)) / (m * xc + 100 - yc)
        xi =    pow((1+mf) , ((g2-1)))    *    (   xc * (100 - yc) * pow(((100-c)/(100-yc)) , (1/g2))   / (m * xc + 100 - yc))

    else:
        # below cusp
        # xi = (1-mf) ** (g1 - 1 )  * ((yc*(c/yc)**(1.0/g1)) / (yc/xc-m))
        xi = pow((1-mf) , (g1 - 1 ))  * ((yc*pow((c/yc) , (1.0/g1))) / (yc/xc-m))
    # print(xi)
    yi = m * xi +c
    return [xi,yi]

findCurveIntersection(80,yc,xc,m,g1,g2)

