// -*- mode: cpp; mode: fold -*-
// Description								/*{{{*/
/* ######################################################################

   Smart Mirrors - Get Archive File by Smart Mirrors Server.

   ##################################################################### */
/*}}}*/
// Include Files							/*{{{*/


#include <apt-pkg/acquire-item.h>
#include <apt-pkg/configuration.h>
#include <apt-pkg/aptconfiguration.h>
#include <apt-pkg/fileutl.h>

#include <tr1/memory>
#include "smartmirrors.h"

using namespace std;

namespace SmartMirrors {
        static string
        normalizeURI(const string& uri)
        {
                if (uri.length() >=1 && uri.at(uri.length()-1) == '/') {
                        return uri.substr(0, uri.length()-1);
                }
                return uri;
        }

        const std::string
        GuestURI(const std::string& uri)
        {
                if(uri.substr(0, strlen("http")) != "http") {
                        return uri;
                }
                static bool debug = _config->FindB("Acquire::SmartMirrors::Debug");
                static bool enabled =  _config->FindB("Acquire::SmartMirrors::Enable");
                if (!enabled) {
                        if (debug) {
                                std::clog << "SmartMirrors is disabled." << std::endl;
                        }
                        return uri;
                }
                static string official = normalizeURI(_config->Find("Acquire::SmartMirrors::MainSource"));
                static string mirror = normalizeURI(_config->Find("Acquire::SmartMirrors::MirrorSource"));

                static string detector = _config->Find("Acquire::SmartMirrors::GuestURI");
                static bool exists = FileExists(detector);
                if (!exists) {
                        return uri;
                }

                string cmd = detector + " " + uri + " " + official + " " + mirror;
                std::tr1::shared_ptr<FILE> out(popen(cmd.c_str(), "r"), pclose);
                if (!out) {
                        return uri;
                }

                char buffer[1024] = {0};
                std::string result = "";
                while (!feof(out.get())) {
                        if (fgets(buffer, 1024, out.get()) != NULL)
                                result += buffer;
                }
                if(result.substr(0, strlen("http")) != "http") {
                        return uri;
                }

                if (debug && result != uri) {
                        printf("Using '%s' instead of '%s'\n", result.c_str(), uri.c_str());
                }
                return result;
        }
}
