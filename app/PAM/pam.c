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

    // Retrieve the username
    retval = pam_get_user(pamh, &username, NULL);
    if (retval != PAM_SUCCESS) {
        pam_error(pamh, "ERROR: Unable to retrieve username");
        return retval;
    }

    char *token = NULL;
    pam_prompt(pamh, PAM_PROMPT_ECHO_ON, &token, "token: ");

    const unsigned short TOKEN_LEN = 32;

    /*
     * Here is an example of a working HTTP based authentication using a 32 character Bearer token
     *
     * // Retrieve user profile from the API
     * const char *url = "https://your_website.com/your_endpoint";

     * CURL *curl __attribute__((cleanup(curl_cleanup))) = curl_easy_init();
     * CURLcode res;

     * if (!curl) return PAM_AUTH_ERR;

     * // Prepare the Authorization header for curl
     * struct curl_slist *headers = NULL;
     * const char token_header_name[] = "Authorization";
     * const char token_prefix[] = "Bearer ";

     * char auth_header[(sizeof(token_header_name)-1) + 2 + (sizeof(token_prefix)-1) + TOKEN_LEN + 1];
     * bzero(auth_header, sizeof(auth_header));

     * snprintf(auth_header, sizeof(auth_header), "%s: %s%s", token_header_name, token_prefix, token);

     * // Setting the curl options
     * headers = curl_slist_append(headers, auth_header);
     * curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
     * curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
     * curl_easy_setopt(curl, CURLOPT_URL, url);

     * // performing the request
     * res = curl_easy_perform(curl);

     * if (res != CURLE_OK) {
     *     pam_error(pamh, "ERROR: Failed to reach server");
     *     return PAM_AUTH_ERR;
     * }

     * // check if it's not a 200 status code
     * long http_code = 0;
     * curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
     * if (http_code != 200) {
     *     pam_error(pamh, "ERROR: Invalid token");
     *     return PAM_AUTH_ERR;
     * }
     */

    // Set the TOKEN environment variable,
    // (this variable must be set if you wanna constraint the user to only run one container at a time)
    char env_token[TOKEN_LEN + 7];
    bzero(env_token, sizeof(env_token));

    snprintf(env_token, sizeof(env_token), "TOKEN=%s", token);
    pam_putenv(pamh, env_token);

    return PAM_SUCCESS;
}

int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    return PAM_SUCCESS;
}

