import 'package:flutter/material.dart' hide Element;

import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';

/// 스킬 종류 테두리 (묶음 35)
enum SkillFrame { attack, life, passive, active }

/// 직업 문장 (job_○○, 묶음 35)
class JobEmblem extends StatelessWidget {
  const JobEmblem(this.job, {super.key, this.size = 40});

  final JobId job;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/job_${job.name}.webp',
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => Icon(Icons.workspace_premium_rounded,
            size: size * 0.7, color: AppColors.goldBright),
      );
}

/// 종류 테두리 안에 그림을 약 70%로 가운데 (그림이 512 칸을 꽉 채워 그대로 겹치면 고리 밖으로 나옴)
class FramedArt extends StatelessWidget {
  const FramedArt({
    super.key,
    required this.frame,
    required this.art,
    this.size = 44,
    this.dim = false,
    this.fallback = Icons.bolt_rounded,
  });

  final SkillFrame frame;
  final String art;
  final double size;
  final bool dim;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    Widget w = SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Image.asset('assets/images/$art.webp',
            width: size * 0.7,
            height: size * 0.7,
            errorBuilder: (_, __, ___) => Icon(fallback,
                size: size * 0.5, color: AppColors.goldBright)),
        Image.asset('assets/images/skill_frame_${frame.name}.webp',
            width: size,
            height: size,
            errorBuilder: (_, __, ___) => const SizedBox()),
      ]),
    );
    if (dim) {
      w = ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.25, 0.25, 0.25, 0, 0, //
            0.25, 0.25, 0.25, 0, 0, //
            0.30, 0.30, 0.30, 0, 0, //
            0, 0, 0, 0.85, 0,
          ]),
          child: w);
    }
    return w;
  }
}

/// 스킬 그림 고르기 (묶음 35)
class SkillArt {
  SkillArt._();

  /// 직업 스킬: 첫 공격 스킬 24개는 그 스킬 그림 + 공격 테두리,
  /// 그 밖은 그 직업 문장 + 종류 테두리 (전투 보조는 공격, 생활은 생활)
  /// 묶음 57: 그림이 따로 있는 전투 보조 스킬 · 이름이 바뀐 그림
  static const _ownArt = {
    JobSkill.ironWall, JobSkill.warCry, JobSkill.manaShield, JobSkill.aegis, JobSkill.purify,
    JobSkill.miracle, JobSkill.smokeBomb, JobSkill.guard, JobSkill.taunt, JobSkill.paladinOath,
  };

  /// 묶음 77 #342: 생활 스킬 그림 30장 (assets/images/skill_<id>.webp)
  static const lifeArt = {
    JobSkill.drill, JobSkill.track, JobSkill.manaSense, JobSkill.firstAid, JobSkill.lockpick,
    JobSkill.runTogether, JobSkill.focusForge, JobSkill.masterTouch, JobSkill.quickRepair,
    JobSkill.masterBlade, JobSkill.runeCarve, JobSkill.quickBrew, JobSkill.recipeHunch,
    JobSkill.instantBrew, JobSkill.specialSale, JobSkill.bountyTouch, JobSkill.harvestSense,
    JobSkill.rootPull, JobSkill.sproutCare, JobSkill.trueEye, JobSkill.wideView, JobSkill.memoryRead,
    JobSkill.polish, JobSkill.bargain, JobSkill.knack, JobSkill.regular, JobSkill.bigPack,
    JobSkill.cheer, JobSkill.snackPouch, JobSkill.eggWarm,
  };

  static (SkillFrame, String) job(JobSkill s) {
    final info = JobRules.skill(s);
    if (s == JobSkill.windBlade) return (SkillFrame.attack, 'skill_windArrow');
    if (info.attack || _ownArt.contains(s)) return (SkillFrame.attack, 'skill_${s.name}');
    // 묶음 77 #342: 그림이 있는 생활 스킬은 그 그림 + 생활 테
    if (lifeArt.contains(s)) return (info.isBattle ? SkillFrame.attack : SkillFrame.life, 'skill_${s.name}');
    final owner = JobRules.jobs.firstWhere((j) => j.skills.contains(s),
        orElse: () => JobRules.jobs.first);
    return (
      info.isBattle ? SkillFrame.attack : SkillFrame.life,
      'job_${owner.id.name}'
    );
  }

  /// 숙련 스킬: 액티브는 그 그림 + 액티브 테두리, 패시브는 숙련도 문장 + 패시브 테두리
  static (SkillFrame, String) mastery(Mastery m, {required bool active}) => active
      ? (SkillFrame.active, 'skill_m_${m.name}')
      : (SkillFrame.passive, 'mastery_${m.name}');

  static Widget jobIcon(JobSkill s, {double size = 44, bool dim = false}) {
    final (f, a) = job(s);
    return FramedArt(frame: f, art: a, size: size, dim: dim);
  }

  static Widget masteryIcon(Mastery m,
      {required bool active, double size = 44, bool dim = false}) {
    final (f, a) = mastery(m, active: active);
    return FramedArt(
        frame: f, art: a, size: size, dim: dim, fallback: Icons.auto_awesome);
  }
}
