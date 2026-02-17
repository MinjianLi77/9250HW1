#!/bin/bash
#--------------------------------------------------------------------------------
#  SBATCH CONFIG
#--------------------------------------------------------------------------------
#SBATCH --job-name=MPI_demo        # name for the job
#SBATCH -N 1                       # number of nodes
#SBATCH	--tasks-per-node=32
#SBATCH --mem-per-cpu=2G                       # total memory
#SBATCH --time 0-00:10                 # time limit in the form days-hours:minutes
#SBATCH --mail-user=ssn2n@umsystem.edu    # email address for notifications
#SBATCH --mail-type=FAIL,END           # email types            
#SBATCH --account=lzxvc-stat
#--------------------------------------------------------------------------------

echo "### Starting at: $(date) ###"

## Module Commands
module purge
module spider r
module load r
R


Rscript stat9250_benchmark_opt.R

echo "### Ending at: $(date) ###"