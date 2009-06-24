/* -------------------------------------------------------------------------- *
 *                                   OpenMM                                   *
 * -------------------------------------------------------------------------- *
 * This is part of the OpenMM molecular simulation toolkit originating from   *
 * Simbios, the NIH National Center for Physics-Based Simulation of           *
 * Biological Structures at Stanford, funded under the NIH Roadmap for        *
 * Medical Research, grant U54 GM072970. See https://simtk.org.               *
 *                                                                            *
 * Portions copyright (c) 2009 Stanford University and the Authors.           *
 * Authors: Scott Le Grand, Peter Eastman                                     *
 * Contributors:                                                              *
 *                                                                            *
 * This program is free software: you can redistribute it and/or modify       *
 * it under the terms of the GNU Lesser General Public License as published   *
 * by the Free Software Foundation, either version 3 of the License, or       *
 * (at your option) any later version.                                        *
 *                                                                            *
 * This program is distributed in the hope that it will be useful,            *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of             *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *
 * GNU Lesser General Public License for more details.                        *
 *                                                                            *
 * You should have received a copy of the GNU Lesser General Public License   *
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.      *
 * -------------------------------------------------------------------------- */

#include <stdio.h>
#include <cuda.h>
#include <vector_functions.h>
#include <cstdlib>
#include <string>
#include <iostream>
//#include <fstream>
using namespace std;

#include "gputypes.h"

static __constant__ cudaGmxSimulation cSim;

void SetVerletUpdateSim(gpuContext gpu)
{
    cudaError_t status;
    status = cudaMemcpyToSymbol(cSim, &gpu->sim, sizeof(cudaGmxSimulation));     
    RTERROR(status, "cudaMemcpyToSymbol: SetSim copy to cSim failed");
}

void GetVerletUpdateSim(gpuContext gpu)
{
    cudaError_t status;
    status = cudaMemcpyFromSymbol(&gpu->sim, cSim, sizeof(cudaGmxSimulation));     
    RTERROR(status, "cudaMemcpyFromSymbol: SetSim copy from cSim failed");
}

// Include versions of the kernels with and with center of mass motion removal.

#include "kVerletUpdate.h"
#define REMOVE_CM
#include "kVerletUpdate.h"

void kVerletUpdatePart1(gpuContext gpu)
{
//    printf("kVerletUpdatePart1\n");
    if (gpu->bRemoveCM)
    {
        kVerletUpdatePart1CM_kernel<<<gpu->sim.blocks, gpu->sim.update_threads_per_block, gpu->sim.update_threads_per_block * sizeof(float3)>>>();
        LAUNCHERROR("kVerletUpdatePart1CM");
        gpu->bRemoveCM = false;
    }
    else
    {    
        kVerletUpdatePart1_kernel<<<gpu->sim.blocks, gpu->sim.update_threads_per_block>>>();
        LAUNCHERROR("kVerletUpdatePart1");
    }
}

void kVerletUpdatePart2(gpuContext gpu)
{
//    printf("kVerletUpdatePart2\n");
    if (gpu->bCalculateCM)
    {
        kVerletUpdatePart2CM_kernel<<<gpu->sim.blocks, gpu->sim.update_threads_per_block, gpu->sim.update_threads_per_block * sizeof(float3)>>>();
        LAUNCHERROR("kVerletUpdatePart2CM");
        gpu->bCalculateCM = false;
        gpu->bRemoveCM = true;
    }
    else
    {
        kVerletUpdatePart2_kernel<<<gpu->sim.blocks, gpu->sim.update_threads_per_block>>>();
        LAUNCHERROR("kVerletUpdatePart2");
    }
}

