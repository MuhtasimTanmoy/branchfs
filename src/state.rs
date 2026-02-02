use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

use crate::error::Result;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum BranchState {
    Active,
    Committed,
    Invalid,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BranchInfo {
    pub parent: Option<String>,
    pub state: BranchState,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct State {
    pub base_path: PathBuf,
    pub workspace_path: PathBuf,
    pub branches: HashMap<String, BranchInfo>,
    #[serde(default)]
    pub epoch: u64,
}

impl State {
    pub fn new(base_path: PathBuf, workspace_path: PathBuf) -> Self {
        let mut branches = HashMap::new();
        branches.insert(
            "main".to_string(),
            BranchInfo {
                parent: None,
                state: BranchState::Active,
            },
        );

        Self {
            base_path,
            workspace_path,
            branches,
            epoch: 0,
        }
    }

    pub fn load(path: &Path) -> Result<Self> {
        let content = fs::read_to_string(path)?;
        Ok(serde_json::from_str(&content)?)
    }

    pub fn save(&self, path: &Path) -> Result<()> {
        let content = serde_json::to_string_pretty(self)?;
        fs::write(path, content)?;
        Ok(())
    }
}
