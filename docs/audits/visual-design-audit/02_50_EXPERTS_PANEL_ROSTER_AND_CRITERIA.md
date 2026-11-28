# تشكيل لجنة الـ 50 خبيرًا ومعايير التقييم البصري — مشروع VSP

**نطاق المراجعة:** مراجعة بصرية شاملة (Visual Design Audit Only) لـ `VSP.App` (اللاعب + المالك) و`vsp_website` و`vsp-admin-panel` — **بدون أي تعديل على الكود أو قواعد العمل**.  
**قاعدة عدم التكرار:** تم توزيع التخصصات الخمسين إلى 5 لجان فرعية؛ تُسجَّل كل مشكلة مرة واحدة بمرجع فريد (`VSP-VD-xxx`) وتُذكر التخصصات التي رصدتها لتفادي التكرار.

---

## اللجان والتخصصات الخمسون

### أولاً: القيادة والاستراتيجية التصميمية (1–8)
1. Chief Design Officer • 2. VP of Design • 3. Head of Product Design • 4. Executive Creative Director • 5. Design Director • 6. Principal Product Designer • 7. Senior Product Designer • 8. Design Critic.
- **عدسة التقييم:** وحدة الهوية عبر المنصات الأربع، وضوح عرض القيمة في أول شاشة (First Fold)، وتوازن الكثافة المعرفية في التدفقات الحرجة (الحجز، التسوية المالية، التنافس).

### ثانيًا: التصميم البصري والواجهات (9–24)
9. Senior UI Designer • 10. Principal Visual Designer • 11. Digital Art Director • 12. Mobile Interface Designer • 13. Web Interface Designer • 14. Dashboard Designer • 15. Information Designer • 16. Graphic Designer • 17. Layout and Composition Designer • 18. Visual Hierarchy Specialist • 19. Typography Designer • 20. Color and Contrast Specialist • 21. Iconography Designer • 22. Illustration Designer • 23. Motion Designer • 24. Micro-interaction Designer.
- **عدسة التقييم:** التسلسل البصري، نسب التباين (WCAG AA 4.5:1 / 3:1)، تناسق الأيقونات (`Iconsax` vs `Material`)، الشبكة والهوامش، الحالات الحركية، والاتساق الرقمي للجداول والكروت.

### ثالثًا: العلامة التجارية والتصميم الرياضي (25–30)
25. Brand Strategist • 26. Brand Identity Designer • 27. Brand Experience Designer • 28. Sports Branding Designer • 29. Sports App Visual Designer • 30. Digital Art and Imagery Specialist.
- **عدسة التقييم:** حضور الروح الكروية الحماسية دون فوضى نيون مفرطة، وضوح شخصية "الميدان الاحترافي الداكن" (Dark Pitch Identity)، وجودة عرض صور الملاعب والدروع.

### رابعًا: نظام التصميم والمكونات (31–38)
31. Design System Architect • 32. Design System Designer • 33. Design Token Specialist • 34. Component Design Specialist • 35. Design Pattern Specialist • 36. Design Technologist • 37. Design Consistency Specialist • 38. Design QA Engineer.
- **عدسة التقييم:** التطابق بين `VSP.App` (`vsp_design_tokens.dart`) و`generated_tokens.ts` و`tailwind.config.js` وCSS الفعلي، التخلص من القيم الثابتة (`Colors.white`, hex مبعثرة)، وقابلية التوسع دون overflow.

### خامسًا: التخصصات الدقيقة والتوطين (39–50)
39. Data Visualization Designer • 40. Gamification Designer • 41. Achievement and Badge Designer • 42. Leaderboard Designer • 43. Fintech Interface Designer • 44. Marketplace Interface Designer • 45. Responsive Design Specialist • 46. Dark Mode Designer • 47. Accessibility Designer • 48. Arabic Typography Designer • 49. RTL and Localization Designer • 50. Independent Visual Quality Auditor.
- **عدسة التقييم:** الأرقام الجدولية (`tabularFigures`) في الفواتير والـ KPIs، تدرج ألوان الدروع (`Silver -> Gold -> Diamond -> Elite -> Legendary -> Immortal`)، سلامة الخطوط العربية من `letterSpacing` المكسور والـ line-height الضيق، والاتجاه المنطقي `start/end` في RTL وLTR.
