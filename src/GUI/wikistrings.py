#!/usr/bin/python
# -*- coding: utf-8 -*-

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
# felixsim
#
# Richard Beanland, Keith Evans, Rudolf A Roemer and Alexander Hubert
#
# (C) 2013/14, all right reserved
#
# Version: :VERSION:
# Date:    :DATE:
# Time:    :TIME:
# Status:  :RLSTATUS:
# Build:   :BUILD:
# Author:  :AUTHOR:
#
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
#  This file is part of felixsim.
#
#  felixsim is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  felixsim is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with felixsim.  If not, see <http://www.gnu.org/licenses/>.
#
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

DefaultWiki = r"""
<p><em>Felix</em> is a Bloch wave simulation code, specifically for D-LACBED diffraction patterns. Written and compiled using Fortran 95.</p>

<p>For more information see the <a href="https://github.com/RudoRoemer/Felix/wiki/Download"><strong>Download</strong></a> page</p>

"""

IWriteFLAGWiki = r"""
Controls the amount of information printed to the log file during the simulation (this can be found in the log directory, named with the date and time of simulation).</p>

<p>Silent - No information is printed to the screen, apart from start and stop messages <br />
Crucial information - Only information in subroutines successfully entered are printed <br />
Basic information - 1st level of info is printed: key information is printed <br />
All information - Final level of info: All information is printed to the screen  </p
"""

IImageFLAGWiki = r"""
<p><strong>IImageFLAG</strong></p>

<p>
Determines the type(s) of output images to be produced by <em>Felix</em>.</p>

<p>Montage - Montages of diffraction patterns. Produces one pattern per thickness (per <strong>RDeltaThickness</strong>) in .bin file format<br />
Stack reflections - Individual reflections saved in .bin file format. Reflections will be bundled into separate folders for each thickness<br />
Amplitude and phase - Amplitude and phase images will be saved. Phase and amplitude images will be saved individually for each reflection and labelled -A or -P respectively</p>

<p>Any combination (in any order) of up to three of these options can be specified to suit the user’s requirements. <strong>At least one option must be selected</strong></p>
"""

IOutputFLAGWiki = r"""
<p><strong>IOutputFLAG</strong></p>

<p>Determines the amount of calculated variables which will be saved during the simulation.</p>

<p><em>Not implemented yet, please select 0</em></p>

<p>0 - Nothing is saved (Fastest)<br />
1 - Ug Matrix will be saved in binary format<br />
2 - Eigenspectra is saved in binary format<br />
3 - Wavefunctions are saved in binary format</p>

<p>Any combination (in any order) of up to three of these options can be specified to suit the user’s requirements. See IImageFLAG example for format</p>
"""

IBinorTextFLAGWiki = r"""
<p><strong>IBinorTextFLAG</strong></p>

<p>Select binary or text output files. Binary files are smaller and faster to read/write. Text files on the other hand are easier to import into other programs (for later use).</p>

<p><em>Text Flag not implemented yet</em>
0 - Binary<br />
1 – Text</p>
"""

IScatterFactorMethodFLAGWiki = r"""
<p><strong>IScatterFactorMethodFLAG</strong></p>

<p>Determines method by which to calculate potentials. Kirkland, option zero, is recommended.</p>

<p>Kirkland method (103 elements)<br />
Peng method (98 elements)<br />
Doyle and Turner method (68 elements)<br />
Lobato method (103 elements)</p>
"""

ICentralBeamFLAGWiki = r"""
<p><strong>ICentralBeamFLAG</strong></p>

<p><em>Not yet implemented – please select 1</em></p>

<p>Exclude the [000] beam from the final image(s). This improves the relative intensity</p>

<p>0 - No central beam<br />
1 - Central beam included</p>
"""

IMaskFLAGWiki = r"""
<p><strong>IMaskFLAG</strong></p>

<p>Choose either a circular or square input beam.</p>

<p>Neither setting affects the physics of the simulation. The square beam simplifies the computation, although there is no discernible slow down with the circular beam. It is recommended the user selects the circular beam.</p>

<p>Unchecked - Circular<br />
Checked - Square</p>
"""

IZolzFLAGWiki = r"""
<p><strong>IZolzFLAG</strong></p>

<p>Choose to limit the simulation to the zeroth order laue zone.</p>

<p>Unchecked - No (Includes HOLZ, slower)<br />
Checked - Yes (ZOLZ only, faster)</p>
"""

IAbsorbFLAGWiki = r"""
<p><strong>IAbsorbFLAG</strong></p>

<p>Choose to include absorption in the simulation.</p>

<p><em>Currently, only the proportional model is available (or none).</em></p>
"""

IAnisoDebyeWallerFLAGWiki = r"""
<p><strong>IAnisoDebyeWallerFLAG</strong></p>

<p>Choose to use anisotropic Debye-Waller factors (if available).</p>

<p>Unchecked - No<br />
Checked - Yes</p>
"""

IPseudoCubicFLAGWiki = r"""
<p><strong>IPseudoCubicFLAG</strong></p>

<p>Indicates whether the given directions are expressed in Pseudocubic or Orthorhombic notation.</p>

<p><em>Pseudocubic coordinates not yet implemented, please select Orthorhombic.</em></p>
"""

IXDirectionFLAGWiki = r"""
<p><strong>IXDirectionFLAG</strong></p>

<p>If set to automatic, <em>Felix</em> will ignore any specified X Direction (<strong>IXDirectionX/Y/Z</strong>). It will then take the shortest g-vector as the X direction.</p>

<p>Automatic - Ignore X Direction<br />
Manual - Use X Direction</p>
"""

IPixelCountWiki = r"""
<p><strong>IPixelCount</strong></p>

<p>Pixel Radius of images, simulation scales as the square of this number but primary parallelisation is over pixels (i.e. more pixels, more cores can be used effectively). 64 is good for images, 128+ is better for quantitative analysis.</p>
"""

IMinReflectionPoolWiki = r"""
<p><strong>IMinReflectionPool</strong>* (IMPORTANT)</p>

<p>Controls the minimum number of reflections accessible in the Bloch problem (i.e. during diagonalisation). Ideally this value should be 2-4 times the value of <strong>IMinStrongBeams</strong>.</p>
"""

IMinStrongBeamsWiki = r"""
<p><strong>IMinStrongBeams</strong>* (IMPORTANT)</p>

<p>This parameter sets the minimum number of beams over which the diagonalisation is pre-formed; increasing it will result in greater accuracy of the final diffraction pattern. This will, on the other hand, increase the simulation time.</p>

<p><em>N.B. As the material complexity increases (size of the unit cell/number of reflections), so does the simulation time. The approximate (simple material, <strong>IReflectOut</strong> = 7) simulation times for a single core machine are given below:</em></p>

<p>IMinReflectionPool, IMinStrongBeams, Time (s), Quality of pattern<br />
10 - 50, 7 - 20, Under 1 minute (Usually Seconds), Poor – usually to check correct position of diffraction spots<br />
50 - 150, 20 - 50, Under 10 minutes, Okay – Produces nice pictures. Still not great for quantitative analysis<br />
150 – 500†, 50 – 125, Under 30 minutes, Produces high quality data, can be used to discern various symmetries of the material</p>

<p>†<em>For a material of serious complexity, a very high quality dataset requires up to 1000 IMinReflectionPool &amp; up to 300 IMinStrongBeams – this may take hours.</em></p>
"""

IMinWeakBeamsWiki = r"""
<p><strong>IMinWeakBeams</strong></p>

<p>Minimum number of weak beams with which to perturb the Strong beams.</p>
"""

RBSBmaxWiki = r"""
<p><strong>RBSBmax</strong></p>

<p>Maximum weak beam perturbation strength before the beam is considered strong.</p>
"""

RBSPmaxWiki = r"""
<p><strong>RBSPmax</strong></p>

<p>Maximum weak beam perturbation of a prior weak beam.</p>
"""

RDebyeWallerConstantWiki = r"""
<p><strong>RDebyeWallerConstant</strong></p>

<p>If no Debye-Waller factor is found in the .cif file, this value will be used for all atomic species missing the factor. It determines the effect of thermal vibrations on the final diffraction pattern.
Note: this is the B factor not U</p>
"""

RAbsorptionPerWiki = r"""
<p><strong>RAbsorptionPer</strong></p>

<p>Defines the percentage of absorption applied to the potentials when using the proportional model, this value will be used for all atomic species.</p>
"""

ROuterConvergenceAngleWiki = r"""
<p><strong>ROuterConvergenceAngle</strong>*</p>

<p>Defines the outer convergence angle of the beam (in units of half the minimum g-vector magnitude).  At a value of 1, all beams will touch at their edges. Values greater than 1 will (experimentally) cause beams to overlap. In the simulation, this will not occur.</p>
"""

RInnerConvergenceAngleWiki = r"""
<p><strong>RInnerConvergenceAngle</strong></p>

<p>Defines the inner convergence angle of the beam (same units as outer convergence angle). For most/all simulations it should be set to zero. This parameter cuts out the central convergence angle of the beam (creating a ‘doughnut’ shaped convergent incident beam). This has the effect of cutting out the central portion of the each D-LACBED reflection.</p>
"""

IIncidentBeamDirectionXWiki = r"""
<p><strong>IIncidentBeamDirectionX</strong>*</p>

<p>X Component of the incident beam direction (Zone axis) expressed in the crystal reference frame in real space.</p>
"""

IIncidentBeamDirectionYWiki = r"""
<p><strong>IIncidentBeamDirectionY</strong>*</p>

<p>Y Component of the incident beam direction (Zone axis) expressed in the crystal reference frame in real space.</p>
"""

IIncidentBeamDirectionZWiki = r"""
<p><strong>IIncidentBeamDirectionZ</strong>*</p>

<p>Z Component of the incident beam direction (Zone axis) expressed in the crystal reference frame in real space.</p>
"""

IXDirectionXWiki = r"""
<p><strong>IXDirectionX</strong>†</p>

<p>X component of the chosen X-axis expressed in the crystal reference frame in reciprocal space</p>
"""

IXDirectionYWiki = r"""
<p><strong>IXDirectionY</strong>†</p>

<p>Y component of the chosen X-axis expressed in the crystal reference frame in reciprocal space</p>
"""

IXDirectionZWiki = r"""
<p><strong>IXDirectionZ</strong>†</p>

<p>Z component of the chosen X-axis expressed in the crystal reference frame in reciprocal space</p>

<p>† <em>N.B. If  <strong>IXDirectionFLAG</strong> is set to zero, the above will be disregarded. The x-axis will be defined by the shortest g-vector.</em></p>
"""

INormalDirectionXWiki = r"""
<p><strong>INormalDirectionX</strong>*</p>

<p>X component of the plane normal to the surface of crystal in real space</p>
"""

INormalDirectionYWiki = r"""
<p><strong>INormalDirectionY</strong>*</p>

<p>Y component of the plane normal to the surface of crystal in real space</p>
"""

INormalDirectionZWiki = r"""
<p><strong>INormalDirectionZ</strong>*</p>

<p>Z component of the plane normal to the surface of crystal in real space</p>

<p><em>N.B. Most of the time, the normal direction will be the same as the incident beam direction</em></p>
"""

RAcceleratingVoltageWiki = r"""
<p><strong>RAccelerationVoltage</strong></p>

<p>Acceleration voltage of the microscope expressed in kV</p>
"""

RInitialThicknessWiki = r"""
<p><strong>RInitialThickness</strong></p>

<p>Lower bound thickness to be applied (Angstroms)</p>
"""

RFinalThicknessWiki = r"""
<p><strong>RFinalThickness</strong></p>

<p>Upper Bound Thickness to be Applied (Angstroms)</p>
"""

RDeltaThicknessWiki = r"""
<p><strong>RDeltaThickness</strong></p>

<p>Step between thicknesses (Angstroms)</p>
"""

IReflectOutWiki = r"""
<p><strong>IReflectOut</strong></p>

<p>The number of the reflections to be included in the final image(s)</p>
"""

IImageOutputFLAGWiki  = r"""
<p><strong>IImageOutputFLAG</strong></p>

<p>Choose whether <em>FelixRefine</em> will output images at the conclusion of the refinement</p>

<p>Unchecked - No<br />
Checked - Yes</p>
"""

IDevFLAGWiki = r"""
<p><strong>IDevFLAG</strong></p>

<p><em>Unused, awaiting removal</em></p>
"""

IRefineModeFLAGWiki = r"""
<p><strong>IRefineModeFLAG</strong></p>

<p>Choose the refinement variable(s)</p>

<p>0 - Refine Debye-Waller Factor<br />
1 - Refine Structure Factors (UGs)<br />
2 - Refine Thickness</p>
"""

RAcceptanceAngleWiki = r"""
<p><strong>RAcceptanceAngle</strong></p>

<p>Determines the maximum scattering angle allowed. 0.0 sets no restriction (recommended).</p>
"""

CIFWiki = r"""
<hr />

<h3>felix.cif</h3>

<p>In order to run a diffraction pattern simulation, or refinement, a crystallographic information file (CIF) is required. This provides <em>Felix</em> with the required structural information of the crystal in question.</p>

<p>Unfortunately, CIF files have no strictly agreed standard. Many of the problems encountered in the output images are caused by a CIF file written outside the general standard <em>Felix</em> expects.  As explained in the Read CIF File section, measures have been taken to negate the effects of a wide range of CIF file formats. It is still on the other hand, the root problem of most simulation difficulties.</p>

<p><strong>Read CIF File</strong>† also contains a section defining the CIF file parameters <em>Felix</em> uses.</p>

<p>Three sample files under the folder: /Felix/samples are provided. These are the recommended styles of CIF file for the <em>Felix</em> user.</p>

<p>They were taken from: http://cds.rsc.org/   (Under the ICSD)</p>

<hr />

<h3>felix.sca</h3>

<p>This contains the scattering factors, of which <em>Felix</em> uses to calculate the Structure Factors. The User has a choice of three methods:</p>

<ol>
<li>Kirkland (<em>1</em>)</li><br />
<li>Doyle &amp; Turner (<em>2</em>)</li>
<li>Peng (<em>3</em>)</li>
</ol>

<p>The suggested (and most recent) scattering factor method is Kirkland. All three will work, with a limited effect on the final diffraction pattern.</p>

<p><em>N.B. _Felix_ will soon be updated with the most recent scattering factors</em></p>

<p>It is NOT recommended the user defines, or changes the .sca file, unless they have the required expertise and have thoroughly read the section on <strong>Read Sca File</strong>†.</p>

<p>† To be uploaded soon</p>

<hr />

<h3>felix.hkl (Optional Input file)</h3>

<p>Occasionally, the user may want to look at a certain reflection(s) output by <em>Felix</em>. This file provides the means to do so. <em>FelixSim</em> will run perfectly without the existence of this file. It is therefore not provided. If the user requires it, an example is given below:</p>

<p>The filename has to be called felix.hkl, and placed in the working directory (in the /samples/Si, samples/GaAs etc. directory when using one of the sample materials)</p>

<p>The format is three coordinate numbers, all separated by a line, within square brackets:
i.e.</p>

<pre><code>[1,0,0]
[2,1,0]
[0,0,1]
</code></pre>

<hr />

<h2>Output</h2>

<p><em>Felix</em> outputs a binary image file (montage/individual reflections/amplitude and phase combination) in the working directory (for samples, it is the same directory as the input files). Reflections and amplitude images will be stored in their own directory (which is created in the working directory)  Instructions on how to convert .bin files to an image can be found on the <a href="https://github.com/RudoRoemer/Felix/wiki/Examples"><strong>Examples</strong></a> page.</p>

<h2>References</h2>

<ol>
<li><em>Kirkland, E. J., Advanced Computing in Electron Microscopy, New York: Springer, (1998).</em></li>
<li><em>Peng, L.-M., Ren, G., Dudarev, S. L. &amp; Whelan, M. J. ActaCryst. A52, 257–276 (1996).</em></li>
<li><em>Doyle, P. A. &amp; Turner, P. S. Acta Cryst. A24, 390–397, (1968).</em></li>
</ol>
"""