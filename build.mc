// build.mc - build (and run) a picotls-minc example.
//
// Usage, from this folder:
//   minc run                 build + run examples/01_https_get.mc
//   minc run <file.mc>       build + run any .mc file
//   minc run <x> --no-run    compile only
//   minc build [<file.mc>]   compile only
//   minc clean
//
// The default example connects to www.google.com:443; override with
// TLS_HOST / TLS_PORT / TLS_SNI. Binaries land in build/, named after
// the .mc file's stem, and run with build/ as the working directory.
// Build from this folder so `import picotls;` resolves against lib/.
//
// The compiler is taken from MINC, then PATH, then this folder
// (install: https://minc.dev).

@minc_min_version "0.9.12"

// Older minc ignores the tag above; this forces an error instead.
when !defined(MINC_VERSION) || MINC_VERSION < 9012 {
    minc_0_9_12_or_newer_required please_update_minc;
}

import process;
import file;
import str;

when os(windows) { str EXE_SUFFIX = ".exe"; }
when os(linux) || os(macos) { str EXE_SUFFIX = ""; }

str DEFAULT_EXAMPLE = "examples/01_https_get.mc";

string join_named(str dir, str name, str ext) {
    string base = str_concat(name, ext);
    defer free(base);
    return path_join(dir, base);
}

void die(str s) {
    eprint("{}\n", s);
    exit(1);
    return;
}

// MINC (install dir or binary), then PATH, then this folder.
string find_minc() {
    string env = env_get("MINC");
    if env.len > 0 {
        if path_is_dir(env) {
            string cand = join_named(env, "minc", EXE_SUFFIX);
            free(env);
            return cand;
        }
        return env;
    }
    free(env);

    string onpath = path_which("minc");
    if onpath.len > 0 { return onpath; }
    free(onpath);

    string local = str_concat("./minc", EXE_SUFFIX);
    if path_exists(local) { return local; }
    free(local);

    string none = { .data = null, .len = 0 };
    return none;
}

void list_other_examples() {
    DirList files = dir_list("examples", ".mc", false);
    defer dir_list_free(&files);
    for i32 i = 0; i < files.count; i++ {
        string rel = path_join("examples", files.items[i]);
        defer free(rel);
        if str_equal(rel, DEFAULT_EXAMPLE) { continue; }
        print("    minc run {}\n", rel);
    }
    return;
}

// Run build/<name> with build/ as the working directory. Windows
// resolves a relative program path against the parent's directory,
// POSIX against the child's.
i32 run_built(str name) {
    string from_root = join_named("build", name, EXE_SUFFIX);
    defer free(from_root);
    string from_dir = str_concat("./", name);
    defer free(from_dir);
    ProcCmd c = { .cwd = "build" };
    when os(windows) { c.args[0] = from_root; }
    when os(linux) || os(macos) { c.args[0] = from_dir; }
    ProcResult r = proc_run(&c);
    i32 rc = r.exit_code;
    proc_result_free(&r);
    return rc;
}

void usage() {
    print("usage: minc <run|build|clean> [<file.mc>] [--no-run]\n"
          "  minc run                 build + run the default HTTPS GET example\n"
          "  minc run <file.mc>       build + run any .mc file\n"
          "  minc build [<file.mc>]   compile only\n"
          "  minc clean               remove build/\n");
    return;
}

i32 main() {
    i32 argc = get_argc();
    str verb = "run";
    str target = "";
    bool no_run = false;

    for i32 i = 1; i < argc; i++ {
        str a = str_from_cstr(get_arg(i));
        if str_equal(a, "--no-run") { no_run = true; }
        else if i == 1 {
            // A .mc path in the verb slot means "run this".
            if str_ends_with(a, ".mc") { target = a; }
            else { verb = a; }
        } else if target.len == 0 { target = a; }
    }

    if str_equal(verb, "clean") {
        ignore dir_remove("build");
        print("clean.\n");
        return 0;
    }
    if !str_equal(verb, "run") && !str_equal(verb, "build") {
        usage();
        return 1;
    }

    string minc = find_minc();
    defer free(minc);
    if minc.len == 0 {
        print("\nminc compiler not found.\n"
              "Install it:  powershell -c \"irm minc.dev/install.ps1 | iex\"\n"
              "or set MINC (see install_minc.md).\n");
        die("See README.md (Quickstart) and LICENSE.md.");
    }

    if !path_exists("lib/picotls.mc") {
        die("missing lib/picotls.mc - dist is incomplete");
    }

    if target.len == 0 {
        target = DEFAULT_EXAMPLE;
        print("no source given - using default example: {}\n  other examples:\n", target);
        list_other_examples();
        print("\n");
    }
    if !path_exists(target) {
        eprint("no such file: {}\n", target);
        exit(1);
    }

    str name = path_stem(target);
    ignore dir_create("build");
    string exe = join_named("build", name, EXE_SUFFIX);
    defer free(exe);

    print("compiling {}\n", name);
    ProcCmd c = { .args = { minc, target, "-o", exe } };
    ProcResult r = proc_run(&c);
    i32 rc = r.exit_code;
    proc_result_free(&r);
    if rc != 0 || !path_exists(exe) { die("minc compile failed"); }
    print("built {}\n", exe);

    if str_equal(verb, "run") && !no_run {
        print("running...\n");
        rc = run_built(name);
    }
    return rc;
}
