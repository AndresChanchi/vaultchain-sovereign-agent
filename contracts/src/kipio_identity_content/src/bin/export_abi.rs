use kipio_identity_content::KipioIdentityContent;
use stylus_sdk::abi::export::{handle_license_and_pragma, print_from_args};

fn main() {
    handle_license_and_pragma();
    print_from_args::<KipioIdentityContent>();
}
