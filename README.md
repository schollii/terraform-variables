# Overview

A more natural, more concise, more robust, more documentable and more versatile way of handling
complex input variable structures in terraform!

# Background

I've been using terraform for over 4 years now and I really enjoy it. One thing that its HCL does
well, is provide a nice uncluttered representation of desired state, both the static aspects as well
as the DRY aspects that minimize toil and error: repetition in the form of loops (over lists and
maps), conditionals in the form of the if/then operator and count = 0/1, encapsulation / refactoring
in the form of modules and locals, subdivision in the form of hierarchical structures, and some
useful builtin functions for basic processing.

And despite 20+ years as a software engineer and despite my love for Python, Go and (years back) C++
and C#, I still find HCL way easier to grok than the code equivalent (available in these other
languages via the very impressive pulumi and CDKtf tools). That is, AS LONG AS one stays away from
complicated data structure transformations.

BUT one problem that I've been hitting more and more over the years is terraform stack
configuration: when you have complex systems that have many configuration points, you need an easy
way to configure and document defaults, so that module users only have to provide the bare necessary
overrides, and so that the IDE can provide you with some intellisense. This does not currently exist
in terraform.

I don't have time to try to convince Hashicorp of what I need, so I'm going to try solving it the
following way: create a small wrapper program that uses hclwrite to read my own HCL-based schema and
generates the necessary terraform HCL code to solve all the parametrization issues I face. Details
below.

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
    - complex types can use `optional(child_type)` to indicate optional values
    - tf locals can use `default(variable, defaults)` to substitute defaults into the variable
- these variables can be given a value via `.tfvars` files and command line arguments, which are
  combined as described in the terraform documentation

The above functionality is unable to handle several use cases:

1. It is not possible to specify defaults for attributes of objects in maps and lists. Eg given
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
   there is no way of getting terraform to fill in what is not given in the tfvars.

2. It is not possible to specify different defaults based on other elements. Given eg

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
   This cannot be expressed in terraform.

3. It is not possible to deep-merge values using the variable specification's `default` attribute.
   Eg given the following specification, it should be possible in the tfvars file to specify only
   var.attrib2.attrib4, and the rest should come from the `default`:

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

   However, this does not happen. Instead, attribs 1 and 3 will be null. See `examples/limitation_3`.

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
   be computed before the plan and shown "here is what this will be, if you don't set it"

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

6. Dotted notation is not supported by the terraform CLI `-var` argument.

There are also aspects that likely affect how easy it is to grok the configuration arguments
and therefore productivity and the likelihood of errors:

- Types and default values should be close together, rather than defined in completely separate
  blocks; eg it would be nice if HCL could support something like

   ```terraform
   variable "var" {
     prototype = map(object({
       attrib1 = number null  // defaults to null if not specified in tfvars
       attrib3 = string "abc" // defaults to abc if not specified in tfvars
       attrib4 = bool         // required because no default value, so every object in map 
                             // needs at least this attrib 
     }))
   }
   ```

- Defaults should be visible to the user, it should not be necessary to search for calls
  to `defaults()` in scattered `locals` blocks and read HCL code to figure out what will be the
  defaults for each variable.

- Whatever solution is chosen to address the above limitations,
    - the syntax should be HCL v2 and be simple / natural as
      possible so we don't have to learn a new syntax
    - It must support intellisense on the configuration tree used by the stack
    - Configuration at lower levels of the configuration hierarchy should use the same constructs /
      syntax as root level

# Solutions Considered

- Modify terraform: not likely feasible but if this were to happen, here is what it might look like

  ```hcl
  variable "config" {
    // description of config (so no description attrib required, and tf docs extracts it
    spec = msp(object({ 
      attrib1 number 123 {}
      attrib2 string {} // no value so it is required
      attrib3 bool true {  //< description for attrib3
        sensitive=true
        validation=... // expression that can use any other variables
        ... 
      }
    }))
  }
  ```

  and this would be interpreted correctly as a prototype for the objects of the map in `var.config`
  and fill in all missing data that was not specified in the values obtained from the tfvars.

- JSON/YAML configuraiton files: it is relatively straightforward to create a module that loads json
  or yaml and does (thanks to HCL) all sorts of processing to solve the above issues. The main
  problem that I have encountered with this approach is that since the configuration is loaded as
  part of the plan, intellisense is not available on the config tree. Moreover, this
  approach does not solve all of the limitations mentioned.

    - It is also posslble to create a provider. Since the provider would be written in a full fledge
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

# Solution Chosen

This section describes the latest elements of a solution that addresses all points.

The overall strategy is to define a new file type where one can specify the input variables,
adhering to HCL syntax; a pre-processor then uses hclwrite or similar to process the file,
together with tfvars, and to generate a `variables.tf`.

- The generated file is not meant to be
  edited by humans; any changes there will be lost at the next "rendering" by this
  pre-processor.
- HCL format is quite standard (eg it is easy to reformat HCL in jetbrains IDEs) so it should be
  possible to emit HCL that is at least as readable as your average variables.tf :) Moreover,
  the generated `variables.tf` will be processable by standard tf documentation generation.
- Due to the odd behavior caused by the combination of the `default` attribute of a `variable` and
  omission of some attribs in the `.tfvars` (see limitation #3), this `default` attribute cannot be
  used. Rather, the pre-processor will generate the following:

    - a `variable` block which contains only the type information, sensitivity, etc and an
      empty `default`
    - a `variable` block which contains the final set of input values, without any type
      information, merged from the input specification and the tfvars files
    - a `local` of the same name that uses the `defaults` function to merge the tfvars (which
      terraform will have created from the var) and the second `variable` block

  This strategy will, based on the findings of limitation #3, give all the information
  that is required for type safety in terraform, for documentation of the module, and for
  intellisense of the configuration; AND allow the user to further override simple values in .tfvars
  files (ie they will not be able to remove a map key or list item).

- Due to the nature of inputs tfvars files (which follow various rules regarding auto, json etc)
  , we may need a new file type for tfvars files so that terraform does not see them. There is
  no foreseeable reason to change the syntax of this file.

    - To fix limitation #1, there may be some tfvars loading and merging logic that will be
      necessary to copy from terraform, so that the preprocessor can be called using the same
      syntax eg instead of `terraform plan -var-file something.tfvars -var something=something`,
      the command would
      be `pre-processor-name update-vars -var-file something.tfvars -var something=something`,
      which would combine the command line args and the local "tfvars" files (auto etc but with)
      the same way as terraform plan / apply.

- The basic type specification construct is `VAR_NAME TYPE {DETAILS}` where DETAILS is the
  attributes mentioned in https://www.terraform.io/language/values/variables#arguments except
  for `type` and `description`, namely `default`, `sensitive`, `validation` and `nullable`. The
  only attribute that will be processed by this pre-processor is `default`; the type will be
  obtained from `TYPE` and the description from the comment (this assumes
  that `hclwrite.parseConfig()` makes comments accessible, but it is not clear yet whether that is
  correct).

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