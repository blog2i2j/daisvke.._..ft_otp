NAME				=	ft_otp
CXX					=	c++
CXXFLAGS			=	-std=c++11 -Wall -Wextra -Werror
INCS_DIR			=	incs/
INCS				=	-I incs/
LDFLAGS				=	-L./cryptopp -lcryptopp
INCS				+=	-I cryptopp/
INCS_FILES			=	$(wildcard $(INCS_DIR)*.hpp)
CRYPTOPP_LIB		=	cryptopp/libcryptopp.a

# Secret key files
HEX_KEY_FILE		=	keys/key.hex
BASE32_KEY_FILE		=	keys/key.base32
BAD_KEY_FILE	=	keys/key.base32hex
ENCRYPTED_KEY_FILE	=	ft_otp.key

# ANSI escape codes for stylized output
RESET 		= \033[0m
GREEN		= \033[32m
YELLOW		= \033[33m
RED			= \033[31m

# Logs levels
INFO 		= $(YELLOW)[INFO]$(RESET)
ERROR		= $(RED)[ERROR]$(RESET)
DONE		= $(GREEN)[DONE]$(RESET)


#######################################
#				F I L E S			  #
#######################################

#		S O U R C E  F I L E S		  #

SRCS_DIR			=	srcs/
SRCS_FILES			=	$(notdir $(wildcard $(SRCS_DIR)*.cpp))
SRCS				=	$(addprefix $(SRCS_DIR), $(SRCS_FILES))


#			O B J .  F I L E S		  #

OBJS_DIR			=	objs/
OBJS_FILES			=	$(SRCS_FILES:.cpp=.o)
OBJS				=	$(addprefix $(OBJS_DIR), $(OBJS_FILES))


#######################################
#				R U L E S			  #
#######################################

# A "pseudo-function" to process each type of key file during tests
# Param1: the path to the original secret key
# Param2: option for oathtool --totp ('-b' for base32)
process_test_key = \
	@echo "$(INFO) Testing with a $(2) key..."; \
	echo "$(INFO) Generating and saving the encrypted key to the external file 'ft_otp.key'..."; \
	echo "$(INFO) Running ./$(NAME) -g with $(1) file...\n"; \
	./ft_otp -g $(1); \
	if [ $$? -eq 0 ]; then \
		echo "$(DONE)"; \
		echo "--------------------------------------------------"; \
		echo "$(INFO) Decoding the encrypted key and generating a TOTP code from it..."; \
		echo "$(INFO) Running ./$(NAME) -k with $(ENCRYPTED_KEY_FILE) file...\n"; \
		./ft_otp $(ENCRYPTED_KEY_FILE) -k; \
		if [ $$? -eq 0 ]; then \
			echo "$(DONE)"; \
		else \
			echo "$(ERROR)"; \
		fi; \
	else \
		echo "$(ERROR)"; \
	fi; \
	echo "--------------------------------------------------"; \
	echo "$(INFO) Comparing our TOTP code to the one delivered by 'oathtool'..."; \
	echo "$(INFO) Running oathtool --totp -v with $(1) file...\n"; \
	oathtool --totp $(3) $(shell cat $(1)) -v; \
	if [ $$? -eq 0 ]; then \
		echo "$(DONE)"; \
	else \
		echo "$(ERROR)"; \
	fi


#		  B U I L D  R U L E S		  #

.PHONY: all clean fclean re hex b32 err tests

all: $(NAME)

# Main target
$(NAME): $(CRYPTOPP_LIB) $(OBJS) $(INCS_FILES)
	$(CXX) $(OBJS) -o $@ $(LDFLAGS)

$(OBJS_DIR)%.o: $(SRCS_DIR)%.cpp $(INCS_DIR)
	mkdir -p $(OBJS_DIR)
	$(CXX) $(INCS) $(CXXFLAGS) -o $@ -c $<


#            C R Y P T O P P          #

# If cryptopp folder is missing, download it, then compile.
# If only the library is missing, compile it.
$(CRYPTOPP_LIB):
	@if [ ! -d "cryptopp" ]; then \
		git clone https://github.com/weidai11/cryptopp.git; \
	fi
	make -C cryptopp/


#              T E S T I N G          #

# Test all keys
tests:
	@echo "$(INFO) Starting tests..."
	@echo "\n"
	@echo "$(INFO) ##################################################"
	@echo "$(INFO) #                 H     E    X                   #"
	@echo "$(INFO) ##################################################"
	@$(MAKE) hex
	@echo "\n\n"
	@echo "$(INFO) ##################################################"
	@echo "$(INFO) #                 B A S E  3 2                   #"
	@echo "$(INFO) ##################################################"
	@$(MAKE) b32
	@echo "\n\n"
	@echo "$(INFO) ##################################################"
	@echo "$(INFO) #                B A D   K E Y                   #"
	@echo "$(INFO) ##################################################"
	@$(MAKE) err
	@echo "$(INFO) Tests completed."

# Targets to call a pseudo function for a specific key
hex: all
	$(call process_test_key, $(HEX_KEY_FILE), "Hex")

b32: all
	$(call process_test_key, $(BASE32_KEY_FILE), "Base32", "-b")

err: all
	$(call process_test_key, $(BAD_KEY_FILE), "bad")


# C L E A N  &  O T H E R  R U L E S  #

RM = rm -rf

clean:
	$(RM) $(OBJS_DIR)

fclean: clean
	$(RM) $(NAME)

re: fclean all