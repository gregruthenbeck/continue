import GenerateTerminalCommand from "./cmd";
import CommentSlashCommand from "./comment";
import CommitMessageCommand from "./commit";
import DraftIssueCommand from "./draftIssue";
import EditSlashCommand from "./edit";
import GregSlashCommand from "./greg";
import HttpSlashCommand from "./http";
import ReviewMessageCommand from "./review";
import ShareSlashCommand from "./share";
import OnboardSlashCommand from "./onboard";

export default [
  DraftIssueCommand,
  ShareSlashCommand,
  GenerateTerminalCommand,
  GregSlashCommand,
  EditSlashCommand,
  CommentSlashCommand,
  HttpSlashCommand,
  CommitMessageCommand,
  ReviewMessageCommand,
  OnboardSlashCommand,
];
