#include <security/pam_modules.h>
#include <security/pam_ext.h>
#include <string.h>
#include <unistd.h>
#include <curl/curl.h>

void curl_cleanup(CURL **curl) {
	if (*curl) {
		curl_easy_cleanup(*curl);
	}
}

int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv) {
	const char *username;
	int retval;

	CURL *curl __attribute__((cleanup(curl_cleanup))) = curl_easy_init();
	CURLcode res;

	if (!curl) return PAM_AUTH_ERR;

	// Retrieve the username
	retval = pam_get_user(pamh, &username, NULL);
	if (retval != PAM_SUCCESS) {
		pam_error(pamh, "ERROR: Unable to retrieve username");
		return retval;
	}

	char *token = NULL;
	pam_prompt(pamh, PAM_PROMPT_ECHO_ON, &token, "42CTF token: ");

	// Retrieve user profile from the API
	// https://42ctf.org/accounts/me/<token>
	char url[66];
	snprintf(url, sizeof(url), "https://42ctf.org/en/accounts/me/%s", token);

	curl_easy_setopt(curl, CURLOPT_URL, url);
	res = curl_easy_perform(curl);

	if (res != CURLE_OK) {
		pam_error(pamh, "ERROR: Failed to reach the 42CTF server");
		return PAM_AUTH_ERR;
	}

	// check if it's not a 200 status code
	long http_code = 0;
	curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
	if (http_code != 200) {
		pam_error(pamh, "ERROR: Invalid token");
		return PAM_AUTH_ERR;
	}

	char env_token[39];
	snprintf(env_token, sizeof(env_token), "TOKEN=%s", token);

	pam_putenv(pamh, env_token);
	return PAM_SUCCESS;
}

int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
	return PAM_SUCCESS;
}

