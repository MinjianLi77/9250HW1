install.packages(c("foreach", "doSNOW", "parallel"), repos = "https://cloud.r-project.org")

suppressPackageStartupMessages({
  library(foreach)
  library(doSNOW)
  library(parallel)
})

# 1. Setup Data
lut <- -cos(2 * (0:255))
N1 <- 1e3; N2 <- 2e3; N_tot <- 64
core_grid <- c(4, 8, 16, 32, 64)

set.seed(1)
vi_v <- runif(N1, min = 0, max = 1024)
vd_s <- matrix(rnorm(N1 * N2), nrow = N1)

d_val <- as.integer(round(vi_v %% 256))
trig  <- lut[d_val + 1L]
rs    <- rowSums(vd_s)
denom <- nrow(vd_s) * ncol(vd_s)

# 2. Serial Baseline
serial_time <- system.time({
  Res_serial <- numeric(N_tot)
  for (iter in 1:N_tot) {
    Res_serial[iter] <- sum(rs * trig) / (denom * cos(iter))
  }
})[["elapsed"]]
cat("Serial elapsed (sec):", serial_time, "\n")

# 3. Respect Slurm allocation
slurm_cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = NA))
if (is.na(slurm_cpus)) slurm_cpus <- as.integer(Sys.getenv("SLURM_NTASKS", unset = 1))

results <- data.frame(
  ncores = core_grid,
  elapsed_sec = NA_real_,
  speedup_vs_serial = NA_real_
)

# 4. Parallel Loop
for (k in seq_along(core_grid)) {
  # Don't try to use more cores than Slurm gave you or more tasks than exist
  ncores <- min(core_grid[k], slurm_cpus, N_tot)
  cat("\n--- Running with", ncores, "cores ---\n")
  
  # Use 'outfile = ""' to see worker logs in your Slurm .out file if needed
  cl <- parallel::makeCluster(ncores, type = "SOCK")
  doSNOW::registerDoSNOW(cl)
  
  elapsed <- tryCatch({
    system.time({
      # CRITICAL FIX: .export sends the data to the worker nodes
      Res_par <- foreach(iter = 1:N_tot, 
                         .combine = c, 
                         .export = c("rs", "trig", "denom")) %dopar% {
                           sum(rs * trig) / (denom * cos(iter))
                         }
    })[["elapsed"]]
  }, error = function(e) {
    message("Parallel run failed for ncores=", ncores, ": ", conditionMessage(e))
    NA_real_
  })
  
  parallel::stopCluster(cl)
  
  results$elapsed_sec[k] <- elapsed
  results$speedup_vs_serial[k] <- if (is.finite(elapsed)) serial_time / elapsed else NA_real_
  cat("Elapsed (sec):", elapsed, "\n")
}

# 5. Output and Plotting
print(results)
write.csv(results, "runtime_vs_cores.csv", row.names = FALSE)

ok <- is.finite(results$elapsed_sec)
if (any(ok)) {
  pdf("runtime_vs_cores.pdf", width = 7, height = 5)
  plot(results$ncores[ok], results$elapsed_sec[ok], type = "b",
       pch = 19, col = "blue",
       xlab = "Number of cores",
       ylab = "Elapsed time (seconds)",
       main = "Running time vs number of cores (foreach/doSNOW)")
  grid()
  dev.off()
  cat("\nWrote: runtime_vs_cores.csv and runtime_vs_cores.pdf\n")
}