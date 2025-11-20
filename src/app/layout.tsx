import "@mantine/core/styles.css";

import {
  ColorSchemeScript,
  MantineProvider,
  mantineHtmlProps,
} from "@mantine/core";
import { PublicEnvScript } from "next-runtime-env";
import Script from "next/script";

export const metadata = {
  title: "My little nigg",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const analyticsID = process.env.NEXT_PUBLIC_ANALYTICS_ID;
  return (
    <html lang="en" {...mantineHtmlProps}>
      <head>
        <ColorSchemeScript defaultColorScheme="dark" />
        <PublicEnvScript />
      </head>
      <body style={{ background: "var(--mantine-color-dark-9)" }}>
        <MantineProvider defaultColorScheme="dark">{children}</MantineProvider>
      </body>
      <Script
        async
        src="https://umami.bart0llo.dev/script.js"
        data-website-id={analyticsID}
      />
    </html>
  );
}
