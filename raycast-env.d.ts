/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {};

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences;

declare namespace Preferences {
  /** Preferences accessible in the `send-book-to-kindle` command */
  export type SendBookToKindle = ExtensionPreferences & {
    /** Sender Address - Email address approved to send documents to your Kindle. */
    senderAddress?: string;
    /** SMTP Host - Hostname of the SMTP server used for delivery. */
    smtpHost?: string;
    /** SMTP Port - SMTP port from 1 through 65535; typically 465 or 587. */
    smtpPort?: string;
    /** Security Mode - Require implicit TLS or a STARTTLS upgrade before authentication. */
    securityMode?: "implicit_tls" | "starttls";
    /** Username - Username used to authenticate with the SMTP server. */
    username?: string;
    /** App Password - Application-specific password used for SMTP authentication. */
    appPassword?: string;
    /** Kindle Address - Personal Send to Kindle address ending in @kindle.com. */
    kindleAddress?: string;
  };
}

declare namespace Arguments {
  /** Arguments passed to the `send-book-to-kindle` command */
  export type SendBookToKindle = {};
}
