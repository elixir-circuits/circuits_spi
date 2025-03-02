# SPDX-FileCopyrightText: 2018 Mark Sebald
# SPDX-FileCopyrightText: 2021 Masatoshi Nishiguchi
# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

# Always warning as errors
if Version.match?(System.version(), "~> 1.10") do
  Code.put_compiler_option(:warnings_as_errors, true)
end

ExUnit.start()
