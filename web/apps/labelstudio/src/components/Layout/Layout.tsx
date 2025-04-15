import { Box } from "@mui/material";
import { ReactNode } from "react";

interface LayoutProps {
  children: ReactNode;
}

export const Layout = ({ children }: LayoutProps) => {
  return (
    <Box
      sx={{
        display: "flex",
        flexDirection: "column",
        height: "100vh",
        width: "100vw",
        overflow: "hidden"
      }}
    >
      <Box
        component="main"
        sx={{
          flexGrow: 1,
          height: "100%",
          overflow: "auto"
        }}
      >
        {children}
      </Box>
    </Box>
  );
};