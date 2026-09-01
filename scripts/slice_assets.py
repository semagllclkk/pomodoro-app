#!/usr/bin/env python3
from PIL import Image
import os
import sys
import math

def find_separators(img, axis=0, thresh_ratio=0.2):
    # axis=0 -> vertical separators (columns), axis=1 -> horizontal (rows)
    w, h = img.size
    pixels = img.convert('RGBA')
    data = pixels.getdata()
    if axis == 0:
        length = w
        span = h
    else:
        length = h
        span = w

    vals = []
    for i in range(length):
        cols = []
        for j in range(span):
            x = i if axis == 0 else j
            y = j if axis == 0 else i
            cols.append(pixels.getpixel((x,y)))
        # compute variance across rows for this column/row
        mean = [sum(c[k] for c in cols)/len(cols) for k in range(3)]
        var = sum(sum((c[k]-mean[k])**2 for k in range(3)) for c in cols)/len(cols)
        vals.append(var)

    gmean = sum(vals)/len(vals)
    gstd = (sum((v-gmean)**2 for v in vals)/len(vals))**0.5
    if gstd == 0:
        return []
    thresh = gmean - thresh_ratio * gstd
    sep_indexes = [i for i,v in enumerate(vals) if v < thresh]

    # cluster contiguous indexes
    clusters = []
    for idx in sep_indexes:
        if not clusters or idx != clusters[-1][-1] + 1:
            clusters.append([idx, idx])
        else:
            clusters[-1][1] = idx

    # take center of clusters
    centers = [ (c[0]+c[1])//2 for c in clusters ]
    return centers

def slice_sheet(path):
    img = Image.open(path)
    basename = os.path.splitext(os.path.basename(path))[0]
    outdir = os.path.join(os.path.dirname(path), basename + '_slices')
    os.makedirs(outdir, exist_ok=True)

    v_seps = find_separators(img, axis=0)
    h_seps = find_separators(img, axis=1)

    xs = [0] + v_seps + [img.size[0]]
    ys = [0] + h_seps + [img.size[1]]

    # if no separators found, try to guess grid by checking aspect
    if len(xs) <= 2 and len(ys) <= 2:
        # assume horizontal strip of equal pieces, try to detect by bright columns
        # fallback to 1 row, N cols where N is 1..8 by trying to find good tile width
        W, H = img.size
        possible = []
        for cols in range(1,9):
            if W % cols == 0:
                tilew = W//cols
                possible.append(cols)
        cols = possible[-1] if possible else 1
        xs = [i*(img.size[0]//cols) for i in range(cols+1)]
        ys = [0, img.size[1]]

    count = 0
    for yi in range(len(ys)-1):
        for xi in range(len(xs)-1):
            left = xs[xi]
            right = xs[xi+1]
            top = ys[yi]
            bottom = ys[yi+1]
            if right-left <=0 or bottom-top <=0:
                continue
            box = (left, top, right, bottom)
            crop = img.crop(box)
            # skip empty crops
            bbox = crop.getbbox()
            if not bbox:
                continue
            count += 1
            outpath = os.path.join(outdir, f"{basename}_{count:02d}.png")
            crop.save(outpath)
            print('Saved', outpath)

    if count == 0:
        print('No slices produced.')
    else:
        print(f'Total slices: {count} in {outdir}')

def main():
    if len(sys.argv) < 2:
        print('Usage: slice_assets.py path/to/sheet.jpg')
        sys.exit(1)
    slice_sheet(sys.argv[1])

if __name__ == '__main__':
    main()
