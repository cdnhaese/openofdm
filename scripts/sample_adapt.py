#!/usr/bin/env python3

import argparse
from cmath import polar, rect
from math import radians
import numpy as np
import os
import struct

def arg_parser():
	parser = argparse.ArgumentParser()
	parser.add_argument('sample_in', help="Sample file to load samples from.")
	parser.add_argument('sample_out', help="Sample file to write adapted samples to.")
	parser.add_argument('radius', help="Increase in the radius in percentage [0-1]", type=float)
	parser.add_argument('angle', help="Phase offset in degrees.", type=float)
	return parser

def test():
	args = arg_parser().parse_args()

	args.sample_in = os.path.abspath(args.sample_in)
	args.sample_out = os.path.abspath(args.sample_out)
	
	radius = args.radius
	angle = radians(args.angle)

	extension = os.path.splitext(args.sample_in)[-1]
	if extension == '.dat':
		samples_in = np.fromfile(args.sample_in, dtype=np.int16)
	elif extension == '.txt':
		samples_in = []
		with open(args.sample_in, 'r') as infile:
			for line in infile:
				i,q = line.split()
				samples_in.extend([int(i), int(q)])
		samples_in = np.array(samples_in, dtype=np.int16)
	else:
		print('Unknown file')
		exit(1)

	samples_out = []
	for idx in range(0, samples_in.shape[0], 2):
		c = complex(samples_in[idx], samples_in[idx+1])
		r, phi = polar(c)
		r = args.radius * r
		phi = phi + angle
		res = rect(r, phi)
		samples_out.extend([res.real, res.imag])

	if extension == '.dat':
		samples_out = np.array(samples_out, dtype=np.int16)
		samples_out.tofile(args.sample_out)
	elif extension == '.txt':
		with open(args.sample_out, 'w') as outfile:
			for idx in range(0, len(samples_out), 2):
				outfile.write(f'{int(samples_out[idx])} {int(samples_out[idx+1])}\n')

if __name__ == '__main__':
	test()
