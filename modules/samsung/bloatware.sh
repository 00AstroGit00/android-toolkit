#!/data/data/com.termux/files/usr/bin/bash
#
# samsung/bloatware.sh — Samsung bloatware listing submodule
#
# Provides samsung_list_bloatware() with 100+ Samsung packages
# organized by safety level (safe, moderate, aggressive).
#
# Part of the Android Toolkit.

##############################################
# List Samsung bloatware candidates organized by safety level.
# Arguments:
#   $1: optional level filter (safe|moderate|aggressive|all)
##############################################
samsung_list_bloatware() {
    if ! detect_is_samsung; then
        return 0
    fi

    local filter="${1:-all}"

    log_section "Samsung Bloatware Candidates"

    # ── SAFE: Generally safe to disable ──
    local safe_bloatware=(
        # Bixby (if not using voice assistant)
        "com.samsung.android.bixby.wakeup"
        "com.samsung.android.bixby.agent"
        "com.samsung.android.bixby.agent.dummy"
        "com.samsung.android.bixby.server"
        "com.samsung.android.bixby.voiceinput"
        "com.samsung.android.app.settings.bixby"
        "com.samsung.systemui.bixby"
        # Bixby Vision
        "com.samsung.android.bixbyvision.framework"
        "com.samsung.android.visionintelligence"
        # Samsung Free / Spage
        "com.samsung.android.app.spage"
        # AR Zone (AR features most users don't use)
        "com.samsung.android.arzone"
        "com.samsung.android.aremoji"
        "com.samsung.android.aremojieditor"
        "com.samsung.android.ardrawing"
        "com.samsung.android.stickercenter"
        "com.sec.android.mimage.avatarstickers"
        # Samsung Internet extras
        "com.samsung.android.service.livedrawing"
        "com.samsung.android.service.peoplestripe"
        # Facebook (pre-installed spyware)
        "com.facebook.appmanager"
        "com.facebook.services"
        "com.facebook.system"
        # LinkedIn (pre-installed)
        "com.linkedin.android"
        # Microsoft Office (pre-installed)
        "com.microsoft.office.excel"
        "com.microsoft.office.word"
        "com.microsoft.office.powerpoint"
        # Samsung tips
        "com.samsung.android.app.tips"
        # Samsung Pass (if not using biometrics for login)
        "com.samsung.android.samsungpass"
        "com.samsung.android.samsungpassautofill"
        # Samsung Global Goals
        "com.samsung.android.globalgoals"
        # Samsung Customization Service (privacy)
        "com.samsung.android.rubin.app"
        # Samsung TV+
        "com.samsung.android.tvplus"
        # Samsung Kids Mode
        "com.samsung.android.kidsinstaller"
        "com.samsung.android.app.camera.sticker.facearavatar.preload"
        # Edge panel plugins (if not using Edge panels)
        "com.samsung.android.app.appsedge"
        # Samsung EasyOneHand
        "com.sec.android.easyonehand"
        # Samsung Safety Information
        "com.samsung.safetyinformation"
        # Google Meet (pre-installed)
        "com.google.android.apps.tachyon"
        # Netflix (pre-installed, can reinstall)
        "com.netflix.partner.activation"
        # Google AR Core (if not using AR)
        "com.google.ar.core"
    )

    # ── MODERATE: May affect some Samsung features ──
    local moderate_bloatware=(
        # Samsung Health (if not using fitness tracking)
        "com.sec.android.app.shealth"
        # Samsung Video Player
        "com.samsung.android.video"
        # Galaxy Store (if using Play Store only)
        "com.sec.android.app.samsungapps"
        # Dynamic Lock / Wallpaper services
        "com.samsung.android.dynamiclock"
        # Samsung Reminder
        "com.samsung.android.app.reminder"
        # Samsung Notes (only if using alternative)
        "com.samsung.android.app.notes"
        # Samsung Smart Switch
        "com.sec.android.easyMover"
        "com.sec.android.easyMover.Agent"
        # PENUP (drawing app for S-Pen)
        "com.samsung.android.liveart"
        # Samsung Voice Recorder
        "com.sec.android.app.voicenote"
        # Samsung Weather
        "com.sec.android.daemonapp"
        # Samsung Calendar (if using Google Calendar)
        "com.samsung.android.calendar"
        # Samsung Calculator (if using alternative)
        "com.sec.android.app.popupcalculator"
        # Samsung Members
        "com.samsung.android.voc"
        # Samsung Cloud (if using Google Backup)
        "com.samsung.android.scloud"
        # Samsung Wallpaper and Style
        "com.samsung.android.app.dressroom"
        # Samsung Handwriting Service
        "com.samsung.android.sdk.handwriting"
        # Samsung Wearable Manager
        "com.samsung.android.app.watchmanagerstub"
        "com.samsung.android.app.watchmanager"
        "com.samsung.android.waterplugin"
        # Samsung SmartThings
        "com.samsung.android.oneconnect"
        # Samsung Internet (if using Chrome)
        "com.sec.android.app.sbrowser"
        # Samsung Game Booster (separate from GOS)
        "com.samsung.android.game.gametools"
        # Samsung Dual Messenger
        "com.samsung.android.da.daagent"
        # Google Photos (if using Samsung Gallery)
        "com.google.android.apps.photos"
        # Google Sheets (if not needed)
        "com.google.android.apps.docs.editors.sheets"
        # Google Docs (if not needed)
        "com.google.android.apps.docs"
        # Google YouTube Music (if using Spotify/other)
        "com.google.android.apps.youtube.music"
    )

    # ── AGGRESSIVE: May break significant features ──
    local aggressive_bloatware=(
        # Samsung Routines
        "com.samsung.android.app.routines"
        # Samsung LED Back Cover
        "com.samsung.android.app.ledbackcover"
        # Smart Edge (Edge Panel) — core feature
        "com.samsung.android.app.smartedge"
        # Samsung AR Emoji / Quick Share
        "com.samsung.android.ardrawing"
        # Samsung AlwaysOnDisplay
        "com.samsung.android.app.aodservice"
        # Samsung DeX — only if you don't use DeX
        "com.sec.android.dexsystemui"
        "com.sec.android.desktopmode.uiservice"
        "com.sec.android.app.desktoplauncher"
        # Samsung Universal Switch
        "com.samsung.android.universalswitch"
        # Samsung Story Service (Gallery stories)
        "com.samsung.storyservice"
        # Samsung Air Command (S-Pen)
        "com.samsung.android.service.aircommand"
        # Google Messages (if using Samsung Messages)
        "com.google.android.apps.messaging"
        # Google TTS (Speech services)
        "com.google.android.tts"
        # Google TalkBack
        "com.google.android.marvin.talkback"
        # Samsung TalkBack
        "com.samsung.android.accessibility.talkback"
        # Samsung Wallet/Pay (if not using)
        "com.samsung.android.spay"
        "com.samsung.android.spayfw"
        # Samsung Printing
        "com.android.bips"
        "com.google.android.printservice.recommendation"
        # Samsung Device Care (if using alternatives)
        "com.samsung.android.lool"
        # Google Daydreams
        "com.android.dreams.basic"
        "com.android.dreams.phototable"
        # Android Easter Egg
        "com.android.egg"
        # Android Live Wallpaper Picker
        "com.android.wallpaper.livepicker"
        # Android Bookmark Provider
        "com.android.bookmarkprovider"
        # Android VPN Dialogs
        "com.android.vpndialogs"
        # Android MMS Service
        "com.android.mms.service"
        # Android SIM Toolkit
        "com.android.stk"
    )

    echo ""
    echo "  Samsung Bloatware Candidates (filter: $filter)"
    echo "  ─────────────────────────────────────────────────"
    echo ""

    local total_found=0

    if [[ "$filter" == "safe" || "$filter" == "all" ]]; then
        echo "  ── Safe to Disable ──"
        echo "  (Generally safe, won't break core Samsung features)"
        echo ""
        local count=0
        for pkg in "${safe_bloatware[@]}"; do
            if backend_package_installed "$pkg" 2>/dev/null; then
                echo "    ✓ $pkg"
                count=$((count + 1))
                total_found=$((total_found + 1))
            fi
        done
        if [[ "$count" -eq 0 ]]; then
            echo "    (none found installed)"
        fi
        echo ""
    fi

    if [[ "$filter" == "moderate" || "$filter" == "all" ]]; then
        echo "  ── Moderate Risk ──"
        echo "  (May affect specific Samsung features you might use)"
        echo ""
        local count=0
        for pkg in "${moderate_bloatware[@]}"; do
            if backend_package_installed "$pkg" 2>/dev/null; then
                echo "    ⚠ $pkg"
                count=$((count + 1))
                total_found=$((total_found + 1))
            fi
        done
        if [[ "$count" -eq 0 ]]; then
            echo "    (none found installed)"
        fi
        echo ""
    fi

    if [[ "$filter" == "aggressive" || "$filter" == "all" ]]; then
        echo "  ── Aggressive (May Break Features) ──"
        echo "  (Research each package before disabling)"
        echo ""
        local count=0
        for pkg in "${aggressive_bloatware[@]}"; do
            if backend_package_installed "$pkg" 2>/dev/null; then
                echo "    ✗ $pkg"
                count=$((count + 1))
                total_found=$((total_found + 1))
            fi
        done
        if [[ "$count" -eq 0 ]]; then
            echo "    (none found installed)"
        fi
        echo ""
    fi

    echo "  ── Critical: NEVER Remove ──"
    echo "  (Removing these will brick or severely break your device)"
    echo ""
    echo "    ✗ com.samsung.android.honeyboard  (Samsung Keyboard — bootloop risk)"
    echo "    ✗ Knox components                 (Security — device lock risk)"
    echo "    ✗ com.samsung.android.systemui    (System UI — brick risk)"
    echo "    ✗ com.android.shell               (Shell — root access)"
    echo "    ✗ com.android.phone               (Phone — no calls)"
    echo "    ✗ com.android.settings            (Settings — no access)"
    echo "    ✗ com.sec.android.app.launcher    (Launcher — home screen)"
    echo "    ✗ com.samsung.android.phone       (Samsung Phone — no calls)"
    echo "    ✗ com.android.vending             (Google Play Store)"
    echo "    ✗ com.google.android.gms          (Google Play Services)"
    echo "    ✗ com.google.android.gsf          (Google Services Framework)"
    echo "    ✗ com.android.permissioncontroller (Permission controller)"
    echo "    ✗ com.android.packageinstaller    (Package installer)"
    echo "    ✗ com.android.providers.settings   (Settings provider)"
    echo "    ✗ com.android.providers.media      (Media provider)"
    echo "    ✗ com.android.providers.downloads  (Downloads provider)"
    echo "    ✗ com.android.documentsui          (Documents UI)"
    echo "    ✗ com.samsung.android.game.gos     (GOS — handle with care)"
    echo ""

    if [[ "$total_found" -eq 0 ]]; then
        log_info "No known bloatware packages found installed"
    else
        log_info "$total_found bloatware candidate(s) found across all categories"
        log_info "Use --disable-package <name> to disable after reviewing."
        log_info "Use --list-bloatware safe|moderate|aggressive to filter by risk level."
    fi
}
