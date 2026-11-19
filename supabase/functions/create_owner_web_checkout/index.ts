import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { createHandler } from "./handler.ts";

serve(createHandler({ createClient, env: (name) => Deno.env.get(name), fetch }));
