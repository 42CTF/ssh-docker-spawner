# Makefile for building the pam_docker.so PAM module and setting up symlinks

# Compiler and linker settings
CC := gcc
CFLAGS := -Wall -fPIC
LDFLAGS := -shared -lpam -lcurl

# Source and object files
SRC := pam.c
MODULE := pam_docker.so
PAM_MODULE_DIR := /usr/lib/security
PAM_SSHD_CONFIG := /etc/pam.d/sshd_docker
APP_PAM_DIR := /app/PAM

# Hidden build directory
BUILD_DIR := .obj
OBJ := $(BUILD_DIR)/pam_docker.o

# Default target
all: symlinks

# Create the hidden build directory if it doesn't exist
$(BUILD_DIR):
	@mkdir -p $@

# Rule to compile the PAM module
$(MODULE): $(OBJ) | $(BUILD_DIR)
	@echo "  LD      $@"
	$(CC) $(OBJ) -o $@ $(LDFLAGS)
	@echo "Successfully built $@"

# Rule to generate the object
$(OBJ): $(SRC) | $(BUILD_DIR)
	@echo "  CC      $<"
	$(CC) $(CFLAGS) -c $< -o $@

# Rule to create symlinks
symlinks: $(MODULE)
	@echo "  LINK    $(PAM_MODULE_DIR)/$(MODULE)"
	@mkdir -p $(PAM_MODULE_DIR)
	@ln -sf $(APP_PAM_DIR)/$(MODULE) $(PAM_MODULE_DIR)/$(MODULE)
	@echo "  LINK    $(PAM_SSHD_CONFIG)"
	@ln -sf $(APP_PAM_DIR)/sshd_docker $(PAM_SSHD_CONFIG)
	@echo "Symlinks updated"

# Rule to clean up object files and the module
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR) $(MODULE)

# Rule to rebuild the module and update symlinks
rebuild: clean all

# Rule to install: create directories and move the module
install: all
	@echo "Installing module..."
	@install -d $(PAM_MODULE_DIR)
	@install -m 755 $(MODULE) $(PAM_MODULE_DIR)/
	@echo "Module installed in $(PAM_MODULE_DIR)"

.PHONY: all symlinks clean rebuild install
