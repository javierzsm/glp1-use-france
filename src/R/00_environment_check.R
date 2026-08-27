message("R environment check")
message(R.version.string)

test_data <- data.frame(
  year = 2019:2025,
  value = seq(100, 700, by = 100)
)

print(test_data)
