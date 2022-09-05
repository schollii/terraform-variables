# Overview

Originally: A more natural, more concise, more robust, more documentable and more versatile way of
handling complex input variable structures in terraform!

Now: TBD because
of https://discuss.hashicorp.com/t/request-for-feedback-optional-object-type-attributes-with-defaults-in-v1-3-alpha

# Background

I've been using terraform for a few years now and I really enjoy it. One thing that its HCL does
well, is provide a nice uncluttered representation of desired state - both the static aspects as
well as the DRY aspects that minimize toil and error: repetition in the form of loops (over lists
and maps), conditionals in the form of the if/then operator and count = 0/1, encapsulation /
refactoring in the form of modules and locals, subdivision in the form of hierarchical structures,
and some useful builtin functions for basic processing.

And despite 20+ years as a software engineer and despite my love for Python, Go and (years back) C++
and C#, I find HCL way easier to grok than the code equivalent (available in these other
languages via the very impressive pulumi and CDKtf tools). That is, AS LONG AS one stays away from
complicated data structure transformations. But that's not what this project is about.

ONE problem that I've been hitting more and more over the years is terraform stack
configuration: when you have more than a few infrastructure resources, you need an easy way to
configure and document defaults, so that module users only have to provide the bare necessary
overrides, and so that the IDE can provide you with some intellisense. This does not currently exist
in terraform. Update 2022-09-04: at least until TF 1.2. In TF 1.3, coming up soon, several issues I
face have been addressed.

High level solution is to read custom HCL-based schema and generate the necessary terraform HCL
code to solve all the parametrization issues I face. Details below.

# Status

This project is at the conceptual stage.

Contributions are welcome: additional limitations (use
cases not supported or with complicated workaround), possible gotchas and limitations with the
solution proposed, alternatives to what is being developed here, bug fixes, etc.

# Terraform Configuration Limitations

Terraform currently supports configuration of a root module via the following:

- specifying optional and required arguments to the module via `variable` elements in the
  module's `tf` files;
    - each one specifies variable type, description, default value, sensitivity etc
    - type can be simple like number, bool, string, or complex like list, set, map, object
    - complex types can use `optional(child_type, default)` to indicate optional values
    - if an object is null in tfvars then the default object is created instead of being null
      (which was the behavior till before TF 1.2)
- these variables can be given a value via `.tfvars` files and command line arguments, which are
  combined as described in the terraform documentation.

The above functionality is unable to handle several use cases:

1. Before TF 1.3, it was not possible to specify defaults for attributes of objects in maps and
   lists. Eg given
    ```terraform
    variable "var" {
      type = map(object({
        attrib1 = optional(number)
        attrib3 = optional(string)
        attrib4 = optional(bool)
      }))
    
      default = {
        _key_ = { 
          attrib1 = 123
          attrib3 = "abc"
          attrib4 = true
        } 
      }
    }
    ```
   or the following
    ```terraform
    variable "var" {
      type = map(object({
        attrib1 = optional(number)
        attrib3 = optional(string)
        attrib4 = optional(bool)
      }))
      default = {}
    }
    variable "var_defaults" {
      default = {
        _key_ = {
          attrib1 = 123
          attrib3 = "abc"
          attrib4 = true
        }
      }
    }
    ```
   and given a tfvars file like this
    ```terraform
    var = {
      key_1 = {
        attrib3 = "abc"
      }
      key_2 = {
        attrib4 = true
      }
    }
    ```
   there is no way of getting terraform to fill in what is not given in the tfvars. In TF 1.3,
   one can write `main.tf` and `terraform.tfvars` from `example/ex-1`.

2. Before TF 1.3, it was not possible to deep-merge values using the variable
   specification's `default` attribute.
   Eg given the following specification, it would have been useful in the tfvars file to specify
   only
   `var.attrib2.attrib4`, and the rest should come from the `default`:

    ```terraform
    variable "var" {
      type = object({
        attrib1 = optional(number)
        attrib2 = optional(object({
          attrib3 = optional(string)
          attrib4 = optional(bool)
        }))
      })
    
      default = {
        attrib1 = 123
        attrib2 = {
          attrib3 = "abc"
          attrib4 = true // tfvars will only give this one
        }
      }
    }
    ```

   Instead, attribs 1 and 3 will be null for TF 1.2. Per examples/ex1, TF 1.3 fixes this via a
   default value that can be specified in `optional()`.

3. It is not possible to specify different defaults based on other elements. Given eg

    ```terraform
    variable "var" {
      type = object({
        attrib1 = number
        attrib2 = string
      })
    
      default = {
        attrib1 = 123
        attrib2 = "abc"
      }
    }
    ```

   What if `attrib2` represents the database name, and you would like it to default to `mysql`
   if `attrib`, the database type, is `mysql`, and to `postgres` if the database type is `postgres`?
   This cannot be expressed in the `variable` block; rather, it is necessary to use tf code
   and the plan must succeed.

4. It is not possible to preview what a value will be when it will be computed from other
   variables. Eg

    ```terraform
    variable "var1" {
      type        = string
      default     = null
      description = "If unspecified, will be computed from the cluster name, date and ..."
    }
    ```

   Very often, such default value does not depend on data from the cloud provider, and could
   be computed before the plan and shown "here is what this will be, if you don't set it".
   Admittedly, this is a nice to have, not essential like the previous items.

5. Fields cannot be documented, eg there is no way of documenting attribs 1 - 4

    ```terraform
    variable "var" {
      type = object({
        attrib1 = optional(number)
        attrib2 = optional(object({
          attrib3 = optional(string)
          attrib4 = optional(bool)
        }))
      })
    }
    ```

   This is still true in TF 1.3,
   but [this comment](https://discuss.hashicorp.com/t/request-for-feedback-optional-object-type-attributes-with-defaults-in-v1-3-alpha/40550/45)
   suggests that TF 1.4 might address this issue.

6. Dotted notation is not supported by the terraform CLI `-var` argument.

7. Duplication of variable definitions in sub-modules

The most important are item 3 and item 7.

There are also aspects that likely affect how easy it is to grok the configuration arguments
and therefore productivity and the likelihood of errors:

- Types and default values should be close together. The TF 1.3 `optional()` does this. The
  TF 1.2 experimental `optional()` does not. In TF 1.3, the default is the second argument
  to `optional()`.

- Defaults should be visible to the user, it should not be necessary to search for calls
  to `defaults()` in scattered `locals` blocks and read HCL code to figure out what will be the
  defaults for each variable. UPDATE: This has been fixed in TF 1.3: `defaults()` is gone and
  instead, the ability to have defaults in `optional()` together with proper deep merging of values
  in tfvars fixes this.

- Whatever solution is chosen here to address the above limitations,
    - the syntax should be HCL v2 and be simple / natural as
      possible so we don't have to learn a new syntax
    - It must support intellisense on the configuration tree used by the stack
    - Configuration at lower levels of the configuration hierarchy should use the same constructs /
      syntax as root level

# Solutions Considered

- Modify terraform: not likely feasible for item 3 because it is hard to imagine how `optional()`
  could be extended to fix item 3, since expressions are necessary but not available
  in `variable.type` elements. It would have to look something like

- JSON/YAML configuraiton files: it is relatively straightforward to create a module that loads json
  or yaml and does (thanks to HCL) all sorts of processing to solve the above issues. The main
  problem that I have encountered with this approach is that since the configuration is loaded as
  part of the plan, intellisense is not available on the config tree. Moreover, this
  approach does not solve all of the limitations mentioned.

  It is also posslble to create a provider. Since the provider would be written in a full fledge
  OO / imperative language, it could solve all the limitations faced by a module, EXCEPT for
  intellisense. Support for intellisense is super important.

- Third-party tool: terragrunt, terramate, terraspace, pulumi, cdktf, to name but the main ones, all
  have the potential of removing all these limitations, but to what extent and in what way, would
  require a significant amount of experimentation. Yet, these systems are huge in comparison to what
  is involved here, cover a huge amount more than what we need, and involve very different choices
  that are not all equivalent and will suit different teams for different reasons. Really I'd like a
  way to fix these limitations without choosing one of these systems, so that any of them
  could still be used.

- Use HCL parsing and writing library: hclwrite is such a library, it is in Go which is a nice
  language to use, it is open source, and it seems feasible to use to solve this problem. HCL seems
  to establish syntax and processing of expressions, but not the behavior of functions or the
  meaning of blocks.

- It would be awesome if defaults could be built from expressions using only other variables. This
  would allow for defaults based on actuals, eg if two database types are supported but with
  slightly different defaults, then the actual value of a var could be used
  in `object({dbname=optional(string, var.dbdefaults[var.dbtype])})`, default

# Solution Chosen

This section describes the latest elements of a solution that addresses all points.

The overall strategy is to define a new file type where one can specify the input variables,
adhering to HCL syntax; a pre-processor then uses hclwrite or similar to process the file,
together with tfvars, and to generate a `variables.tf`.

- The generated file is not meant to be edited by humans; any changes there will be lost at the
  next "rendering" by this pre-processor.
- HCL format is quite standard (eg it is easy to reformat HCL in jetbrains IDEs) so it should be
  possible to emit HCL that is at least as readable as your average variables.tf :) Moreover,
  the generated `variables.tf` will be processable by standard tf documentation generation.
- The solution will only support TF 1.3+ due to the very odd experimental behavior of defaults
  before that version. In fact it may be worth waiting for 1.4 support for nested `variable` blocks,
  in that case an additional block `override` might be possible to solve item 3.

To be updated due to TF 1.3: 

- Simple types:

    ```hcl
    my_var1 string {}
    my_var2 number { default=123 } // automatically optional since default given
    my_var3 bool { // automatically required since not default
      sensitive = true 
      nullable = true 
    } 
    ```

- Structured objects:

    ```hcl
    my_var4 object { // automatically required since not default
      sensitive = true 
      nullable = true 

      attribs {
        attrib1 string {} // no default, so it will be required!
        attrib2 bool   {default = true} 
      }
  
      default = object({
        attrib1 = "abc"
      })
    }
    ```

- Lists:

    ```hcl
    my_var5 list { // automatically required since not default
      sensitive = true 
      nullable = true 

      item_spec {
        attrib1 string {} // no default, so it will be required!
        attrib2 bool   {default = true} 
      }
  
      // default = [] // my_var4 is required because default not given

      validation { ... }
    }
    ```

  Also

  ```hcl
    my_var6 list { // automatically required since not default
      item_spec object {
        attribs {
          attrib1 string {} // no default, so it will be required!
          attrib2 bool   {default = true} 
        }
      }
      default = [{attrib1="abc"}, {attrib1="def"}] /* if list not given, this is the default
         otherwise the given list replaces this list entirely, but with each item in the list
         using the defaults from the item_spec (so attrib2 would be true if unspecified) 
         */
    }
    ```

- Maps:

    ```hcl
    my_var7 map {
      sensitive = true 
      nullable = true 

      item_spec object {
        attribs {
          attrib1 string {} // no default, so it will be required!
          attrib2 bool   {default = true}
        } 
      }
  
      // default = {} // required because default not given

      validation { ... }
    }
    ```

  Also

    ```hcl
    my_var8 map {
      item_spec {
        attrib1 string {} // no default, so it will be required!
        attrib2 bool   {default = true} 
      }

      default = {
        key1 = { attrib1 = "abc" }
        key2 = { attrib1 = "def" }
      }
    }
    ```

- The file type for the above terraform variables specification can be `tvs`.

- It is not clear whether hclwrite and other packages in same repo contain the expression evaluation
  engine. Eg pre-processor code should be able to give hcl package a set of key value pairs (where
  key is var name and value is a reference to either a simple or complex object or a function) it
  will evaluate any expression involving those values (or raise appropriate error)

- import

    ```hcl
    config_mod_name import { path = "sub_module/config.tvs" }
    ```
