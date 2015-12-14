#!/usr/bin/env python
import re,sys,irmacode

c=irmacode.Code("code-2008-04-14.txt")

global verbose
verbose=False

sys.argv.pop(0)
classfile="notdefined"
conffile="notdefined"
while len(sys.argv)>0:
	arg=sys.argv.pop(0)
	if arg=="-c":
		if classfile=="notdefined":
			classfile=sys.argv.pop(0)
			#print classfile
		else:
			print "only one train_file allowed"
			sys.exit(10)
	elif arg=="-v":
		verbose=True
		#sys.argv.pop(sys.argv.index("-v"))
	else:
		if conffile=="notdefined":
			conffile=arg
		else:
			print "only one submission_file allowed"
			sys.exit(10)



if classfile!="notdefined":
	f=open(classfile,"r")
	img2code={}
	for l in f:
    		tok=l.split()
    		img2code[tok[0]]=tok[1]
    
	f.close()
else:
	print "train_file needed"
	print """USAGE: ./evaluate_07_08.py [Option] -c train_file submission_file
	Option: -v verbose modality"""
	sys.exit(10)
	
if conffile!="notdefined":
	f=open(conffile)
	errorcount=0.0

	ERerrorcount=0
	ERclassifiedcount=0

	for l in f:
		tok=l.split()

		correct=img2code[tok[0]]
		classified=tok[1]

		#print tok[0], correct,classified
		#print c.CodeToText(correct)
		#print c.CodeToText(classified)

		localE=c.evaluate(correct,classified,verbose)
		errorcount+=localE

		if correct!=classified:
			ERerrorcount+=1
		ERclassifiedcount+=1


		#print tok,localE,errorcount
else:
	print "submission_file needed"	
	print """USAGE: ./evaluate_07_08.py [Option] -c train_file submission_file
	Option: -v verbose modality"""
	sys.exit(10)
    
print "train_file=", classfile, "submission_file=", conffile
print "Error Score:",errorcount,"Total Number of Images:",ERclassifiedcount

